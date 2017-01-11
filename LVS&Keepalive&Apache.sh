### Setup LVS + Keepalive + apache Manual ###
# Auther:   Jimmy Zhou
# Date:     2016-01-10
# Descriptions: Configure LVS for backend web server load balance(This example is two nodes web server).Configure keepalive for ensure director HA. \
#               if master node is down,backup will be take over automatically(This example is two nodes web server). \
# role			     name	   ip
#---------------------------------
# director  	   node1 	192.168.2.100
# director  	   node2	192.168.2.101
# realserver     node3 	192.168.2.102
# realserver  	 node4 	192.168.2.103

###### LVS ######
###### Role director both on node1 and node2 ######
### Configure yum source ###
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
cd /etc/yum.repos.d/
wget http://mirrors.163.com/.help/CentOS6-Base-163.repo
mv CentOS6-Base-163.repo CentOS-Base.repo
yum clean all
yum makecache

### Install ipvs admin tools ###
yum install ipvsadm -y

### Configure VIP both on node1 and node2 ####
ifconfig eth0:0 192.168.2.200 netmask 255.255.255.255 up

### Configure LVS ###
ipvsadm -A -t 192.168.2.200:80 -s rr
ipvsadm -a -t 192.168.2.200:80 -r 192.168.2.102 -g
ipvsadm -a -t 192.168.2.200:80 -r 192.168.2.103 -g
ipvsadm -Ln


###### Role realserver both on node3 and node4 ######
cd /etc/init.d/
vim realserver
### Below is realserver script ###
SNS_VIP=192.168.2.200
. /etc/rc.d/init.d/functions
case "$1" in
start)
       ifconfig lo:0 $SNS_VIP netmask 255.255.255.255 broadcast $SNS_VIP
       /sbin/route add -host $SNS_VIP dev lo:0
       echo "1" >/proc/sys/net/ipv4/conf/lo/arp_ignore
       echo "2" >/proc/sys/net/ipv4/conf/lo/arp_announce
       echo "1" >/proc/sys/net/ipv4/conf/all/arp_ignore
       echo "2" >/proc/sys/net/ipv4/conf/all/arp_announce
       sysctl -p >/dev/null 2>&1
       echo "RealServer Start OK"
       ;;
stop)
       ifconfig lo:0 down
       route del $SNS_VIP >/dev/null 2>&1
       echo "0" >/proc/sys/net/ipv4/conf/lo/arp_ignore
       echo "0" >/proc/sys/net/ipv4/conf/lo/arp_announce
       echo "0" >/proc/sys/net/ipv4/conf/all/arp_ignore
       echo "0" >/proc/sys/net/ipv4/conf/all/arp_announce
       echo "RealServer Stoped"
       ;;
*)
       echo "Usage: $0 {start|stop}"
       exit 1
esac
exit 0
### Start scripts for realserver,start apache server ###
service realserver start
service httpd start

### Conigure testing html website - node3###
vim /var/www/html/index.html
<h1>node3-192.168.2.102</h1>

### Conigure testing html website - node4###
vim /var/www/html/index.html
<h1>node4-192.168.2.103</h1>

### Testing html status is OK or not ###
curl http://192.168.2.200


###### Keepalive ######
###### Role director on node1 - MASTER ######
cd /etc/keepalived
> /etc/keepalived/keepalived.conf

vim /etc/keepalived/keepalived.conf
global_defs {
   notification_email {
         13273980@qq.com
   }
   notification_email_from jimmyzhoujcc@gmail.com
   smtp_server 192.168.2.1
   smtp_connection_timeout 30
   router_id LVS_DEVEL  # 设置lvs的id，在一个网络内应该是唯一的
}
vrrp_instance VI_1 {
    state MASTER   #指定Keepalived的角色，MASTER为主，BACKUP为备
    interface eth0  #指定Keepalived的角色，MASTER为主，BACKUP为备
    virtual_router_id 51  #虚拟路由编号，主备要一致
    priority 100  #定义优先级，数字越大，优先级越高，主DR必须大于备用DR
    advert_int 1  #检查间隔，默认为1s
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.2.200  #定义虚拟IP(VIP)为192.168.2.33，可多设，每行一个
    }
}
# 定义对外提供服务的LVS的VIP以及port
virtual_server 192.168.2.200 80 {
    delay_loop 6 # 设置健康检查时间，单位是秒
    lb_algo wrr # 设置负载调度的算法为wlc
    lb_kind DR # 设置LVS实现负载的机制，有NAT、TUN、DR三个模式
    nat_mask 255.255.255.0
    persistence_timeout 0
    protocol TCP
    real_server 192.168.2.102 80 {  # 指定real server1的IP地址
        weight 3   # 配置节点权值，数字越大权重越高
        TCP_CHECK {
        connect_timeout 10
        nb_get_retry 3
        delay_before_retry 3
        connect_port 80
        }
    }
    real_server 192.168.2.103 80 {  # 指定real server2的IP地址
        weight 3  # 配置节点权值，数字越大权重越高
        TCP_CHECK {
        connect_timeout 10
        nb_get_retry 3
        delay_before_retry 3
        connect_port 80
        }
     }
}

service keepalived start

###### Role director on node2 - BACKUP ######
cd /etc/keepalived
> /etc/keepalived/keepalived.conf

vim /etc/keepalived/keepalived.conf
global_defs {
   notification_email {
         13273980@qq.com
   }
   notification_email_from jimmyzhoujcc@gmail.com
   smtp_server 192.168.2.1
   smtp_connection_timeout 30
   router_id LVS_DEVEL  # 设置lvs的id，在一个网络内应该是唯一的
}
vrrp_instance VI_1 {
    state BACKUP   #指定Keepalived的角色，MASTER为主，BACKUP为备
    interface eth0  #指定Keepalived的角色，MASTER为主，BACKUP为备
    virtual_router_id 51  #虚拟路由编号，主备要一致
    priority 99  #定义优先级，数字越大，优先级越高，主DR必须大于备用DR
    advert_int 1  #检查间隔，默认为1s
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.2.200  #定义虚拟IP(VIP)为192.168.2.33，可多设，每行一个
    }
}
# 定义对外提供服务的LVS的VIP以及port
virtual_server 192.168.2.200 80 {
    delay_loop 6 # 设置健康检查时间，单位是秒
    lb_algo wrr # 设置负载调度的算法为wlc
    lb_kind DR # 设置LVS实现负载的机制，有NAT、TUN、DR三个模式
    nat_mask 255.255.255.0
    persistence_timeout 0
    protocol TCP
    real_server 192.168.2.102 80 {  # 指定real server1的IP地址
        weight 3   # 配置节点权值，数字越大权重越高
        TCP_CHECK {
        connect_timeout 10
        nb_get_retry 3
        delay_before_retry 3
        connect_port 80
        }
    }
    real_server 192.168.2.103 80 {  # 指定real server2的IP地址
        weight 3  # 配置节点权值，数字越大权重越高
        TCP_CHECK {
        connect_timeout 10
        nb_get_retry 3
        delay_before_retry 3
        connect_port 80
        }
     }
}

service keepalived start


###### Validation result ######
### Role director on node1 - MASTER ###
service keepalived stop
service keepalived status
#refresh result url http://192.168.2.200