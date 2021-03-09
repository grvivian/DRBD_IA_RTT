#! /bin/bash

PASS="1234\n";
PERC_JITTER=0.1; #Percentual de Jitter
LATENCIES="10 100 300 500 800";
RATES="100mbit";

function stats { #obtem as estatisticas
  while [ true ]; do #aguardar termino sync no server
    LIST1="$(cat /proc/drbd)";
    if grep -q "bm:0 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0" <<< "${LIST1}"; then
      echo ${LIST1};
      break;
    fi
    sleep 1s;
  done
  
  #echo "Wait slave...";
  while [ true ]; do #aguardar termino sync no slave
    LIST2="$(echo -e ${PASS} | sshpass -p 1234 ssh root@vm2c 'cat /proc/drbd')";
    if grep -q "bm:0 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0" <<< "${LIST2}"; then 
      echo ${LIST2};
      break;
    fi
    sleep 1s;
  done
}

function clean { #limpa a replicação
  echo -e ${PASS} | sudo -S tc qdisc delete dev eth1 root netem; #limpa rede
  rm -fr /pasta/dataset/; #apaga o dataset
  PID=$!;
  wait ${PID};
  sleep 10s;
}

function IA {
  RTT="$(java -jar DRBD_IA.jar -r=$1 -l=$2)";
  #Define o tempo limite para respostas a pacotes keep-alive. 
  #O valor padrão é 0,5 segundos, com um mínimo de 0,1 segundos e um máximo de 3 segundos. A unidade é décimos de segundo.
  RTT="$(echo "(${RTT}/100)" | bc)";
  if [ ${RTT} -gt 30 ]; then
    RTT=30;#3000ms
  elif [ ${RTT} -lt 1 ]; then
    RTT=1;#100ms
  fi
  echo "IA RTT: "${RTT}"00";
  echo -e ${PASS} | sudo -S sed -i -e '/ping-timeout / s/ .*;/ '${RTT}';/' /etc/drbd.d/global_common.conf;   
  echo -e ${PASS} | sudo -S sshpass -p 1234 scp -p /etc/drbd.d/global_common.conf root@vm2c:/etc/drbd.d/global_common$
  echo -e ${PASS} | sudo -S /etc/init.d/drbd reload;
  echo -e ${PASS} | sudo -S sshpass -p 1234 ssh -t root@vm2c '/etc/init.d/drbd reload';
  sleep 10s;
}

for RATE in ${RATES}; do
  for LATENCY in ${LATENCIES}; do
  JITTER="$(echo "(${LATENCY}*${PERC_JITTER})" | bc)";
  echo "------------------------------------";
  clean;
  echo "Rate:"${RATE}" Delay:"${LATENCY}" Jitter:"${JITTER};

  # loss 0.3% duplicate 0.1% corrupt 0.1%
  echo -e ${PASS} | sudo -S tc qdisc add dev eth1 root netem rate ${RATE} delay ${LATENCY}ms ${JITTER}ms distribution normal;
    
  PING="$(ping -q -s 512 -c 3 vm2 | tail -1 )";
  echo ${PING};
  PING="$(echo ${PING} | awk '{print $4}' | cut -d '/' -f 2)";
    
  #IA ${RATE} ${PING};
  echo "NO-IA: 300";

  stats;
  #echo "Copying..";
  INICIO="$(date +%s%N)";
  echo -e ${PASS} | sudo -S dmesg -C; #limpa buffer de erros do kernel
  cp -r /home/glaucio/dataset.zip /pasta/; #copia o dataset para o DRBD
  #PID=$!;
  #wait ${PID};
  sleep 30s;
  echo -e ${PASS} | sudo -S dmesg; #mostra os erros
  stats;  
  FIM="$(date +%s%N)";
  TEMPO="$(echo "(${FIM} - ${INICIO})" | bc)";
  echo ${TEMPO};

  done
done
