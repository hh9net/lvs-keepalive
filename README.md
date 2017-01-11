Setup LVS + Keepalive + apache Manual
=====================================
###### Auther:   Jimmy Zhou
###### Date:     2016-01-10
###### Descriptions: Configure LVS for backend web server load balance(This example is two nodes web server).Configure keepalive for ensure director HA. \
######               if master node is down,backup will be take over automatically(This example is two nodes web server). \
###### role			     name	   ip
######---------------------------------
###### director  	 node1 	192.168.2.100
###### director  	 node2	192.168.2.101
###### realserver     node3 	192.168.2.102
###### realserver  	 node4 	192.168.2.103

