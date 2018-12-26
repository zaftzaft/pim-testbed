conn() {
  ip link add $1-to-$2 type veth peer name $2-to-$1
  ip link set dev $1-to-$2 up
  ip link set dev $2-to-$1 up

  ip link set $1-to-$2 netns $1
  ip -n $1 link set dev $1-to-$2 up
  ip link set $2-to-$1 netns $2
  ip -n $2 link set dev $2-to-$1 up
}

netns_loopback() {
  #ip -n $1 a a 127.0.0.1 dev lo
  ip -n $1 link set dev lo up
}

pid_kill() {
  if [ -e $1 ]; then
    kill `cat $1`
    rm $1
  fi
}


run_frr() {
  netns=$1
  daemon=$2
  port=$3

  file=${daemon}_${netns}
  config=conf/${file}.conf

  pid_kill /var/run/frr/${daemon}_${netns}.pid

  if [ ! -e $config ]; then
    cat << EOF > $config
hostname $netns-${daemon}
password zebra
EOF
  fi

  echo sudo ip netns exec $netns telnet 127.0.0.1 $port > quick/$file

  ip netns exec ${netns} /usr/lib/frr/${daemon} -d -f ${config} -i /var/run/frr/${file}.pid -z /var/run/frr/${file}.vty
}

run_pimd() {
  run_frr $1 zebra 2601
  run_frr $1 ospfd 2604
  run_frr $1 pimd 2611
}

mkdir ./conf
mkdir quick

ip netns add tokyo
netns_loopback tokyo
ip netns add kanag
netns_loopback kanag
ip netns add osaka
netns_loopback osaka

ip -n tokyo a a 172.16.22.1/24 dev tokyo-to-kanag
ip -n tokyo a a 172.16.23.1/24 dev tokyo-to-osaka
ip -n kanag a a 172.16.22.2/24 dev kanag-to-tokyo
ip -n osaka a a 172.16.23.2/24 dev osaka-to-tokyo


# kanag - tokyo - osaka
conn tokyo kanag
conn tokyo osaka

run_pimd tokyo
run_pimd kanag
run_pimd osaka


chown frr:frr -R conf
chmod +x -R quick



#brctl addbr 
