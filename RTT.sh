#!/bin/bash

DEV=eth0;
IP="127.0.0.1";
CONT=50;
PACOTE=512;#MINUS 8 - HEADER SIZE
PERDA=0.5%;
DUPLICADOS=0.5%;
CORROMPIDOS=0.5%;
PERC_JITTER=0.1; #Percentual de Jitter
RATES="100kbit 250kbit 500kbit 750kbit 1mbit 2.5mbit 5mbit 7.5mbit 10mbit 25mbit 50mbit 75mbit \
       100mbit 250mbit 500mbit 750mbit 1gbit";
LATENCIES="10 30 50 70 90 110 130 150 170 190 210 230 250 270 290 310 330 350 370 390 410 430 450";

for RATE in ${RATES} ; do
  for LATENCY in ${LATENCIES}; do
    JITTER="$(echo "(${LATENCY}*${PERC_JITTER})" | bc)";
    tc qdisc delete dev ${DEV} root netem;
    echo "Simulando Rate:" ${RATE} " Latency:" ${LATENCY} " Jitter:" ${JITTER};

    tc qdisc add dev ${DEV} root netem loss ${PERDA} duplicate ${DUPLICADOS} corrupt ${CORROMPIDOS} \
      rate ${RATE} delay ${LATENCY}ms ${JITTER}ms distribution normal;

    PING="$(ping -q -s ${PACOTE} -c ${CONT} ${IP} | tail -1 )"; #RTT
    echo ${PING};
  done
done
