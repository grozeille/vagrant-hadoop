#!/bin/bash
DIR=/vagrant

if [ ! -d $DIR/cache ]; then
	mkdir $DIR/cache
fi

function download {
	if [ ! -f $DIR/cache/$2 ]; then
		wget -nv "${@:4}" \
		-O $DIR/cache/$2 \
		$1
	fi

	cp $DIR/cache/$2 $3
}

function download_and_untargz {
	if [ ! -f $DIR/cache/$2 ]; then
		wget -nv "${@:4}" \
		-O $DIR/cache/$2 \
		$1
	fi

	tar xfz $DIR/cache/$2 -C $3
}

function install_jdk {
	if [ -d /opt/jdk1.8.0_45 ]; then
		return
	fi
	echo "install jdk"

	# install jdk
	cd /opt

	download_and_untargz \
	"http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jdk-8u45-linux-x64.tar.gz" \
		jdk-8u45-linux-x64.tar.gz \
		/opt/ \
		--no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie"
	
	cd /opt/jdk1.8.0_45/

	alternatives --install /usr/bin/java java /opt/jdk1.8.0_45/bin/java 2
	alternatives --install /usr/bin/jar jar /opt/jdk1.8.0_45/bin/jar 2
	alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_45/bin/javac 2
	alternatives --set java /opt/jdk1.8.0_45/bin/java
	alternatives --set jar /opt/jdk1.8.0_45/bin/jar
	alternatives --set javac /opt/jdk1.8.0_45/bin/javac

	echo 'export JAVA_HOME=/opt/jdk1.8.0_45' >> /etc/bashrc
	echo 'export JRE_HOME=/opt/jdk1.8.0_45/jre' >> /etc/bashrc
	echo 'export PATH=$PATH:/opt/jdk1.8.0_45/bin:/opt/jdk1.8.0_45/jre/bin' >> /etc/bashrc

	source /etc/bashrc
	
}

function install_mysql {
	if [ -d /usr/bin/mysql ]; then
		return
	fi

	yum install -y -d1 mysql-server

	# set InnoDB as default engine
	cat $DIR/conf/mysql/my.cnf > /etc/my.cnf

	/sbin/service mysqld start
	chkconfig mysqld on
	
	echo "GRANT ALL ON *.* TO 'root'@'%';" > /tmp/init.sql
	echo "FLUSH PRIVILEGES;" >> /tmp/init.sql
	
	mysql -u root < /tmp/init.sql

}

function install_python {
	if [ -d /opt/anaconda ]; then
		return
	fi

	download \
		"http://repo.continuum.io/archive/Anaconda2-4.0.0-Linux-x86_64.sh" \
		Anaconda2-4.0.0-Linux-x86_64.sh \
		/opt/

	chmod +x /opt/Anaconda2-4.0.0-Linux-x86_64.sh
	/opt/Anaconda2-4.0.0-Linux-x86_64.sh -b -p /opt/anaconda

	echo 'export PYTHON_HOME=/opt/anaconda' >> /etc/bashrc
	echo 'export PATH=$PATH:$PYTHON_HOME/bin' >> /etc/bashrc
	source /etc/bashrc
}


function start_hue {
	chmod +x $DIR/start-hue.sh
	sudo -u vagrant $DIR/start-hue.sh
}

function install_hue {
	if [ -d /opt/hadoop/hue ]; then
		start_hue
		return
	fi

	echo "install HUE"
	# install hue
	download_and_untargz \
		"http://archive.apache.org/dist/maven/maven-3//3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz" \
		apache-maven-3.3.3-bin.tar.gz \
		/opt

	echo 'export MAVEN_HOME=/opt/apache-maven-3.3.3' >> /etc/bashrc
	echo 'export PATH=$PATH:/opt/apache-maven-3.3.3/bin' >> /etc/bashrc
	source /etc/bashrc

	download_and_untargz \
		"https://dl.dropboxusercontent.com/u/730827/hue/releases/3.10.0/hue-3.10.0.tgz" \
		hue-3.10.0.tgz \
		/opt/hadoop

	yum install -y -d1 ant asciidoc cyrus-sasl-devel cyrus-sasl-gssapi gcc gcc-c++ krb5-devel libxml2-devel libxslt-devel make mysql mysql-devel openldap-devel python-devel sqlite-devel openssl-devel gmp-devel cyrus-sasl-plain libffi-devel

	cd /opt/hadoop/hue-3.10.0
	make desktop
	# bug fix: too short timeout for starting spark session
	#cat $DIR/conf/hue/SessionServlet.scala > /opt/hadoop/hue-3.10.0/apps/spark/java/livy-server/src/main/scala/com/cloudera/hue/livy/server/SessionServlet.scala
	make apps
	make install PREFIX=/opt/hadoop

	cat $DIR/conf/hue/hue.ini > /opt/hadoop/hue/desktop/conf/hue.ini

	# configure mysql
	echo "CREATE USER 'hue'@'%' IDENTIFI ED BY 'hue';" > /tmp/init_hue.sql
	echo "CREATE USER 'hue'@'localhost' IDENTIFIED BY 'hue';" >> /tmp/init_hue.sql
	echo "CREATE USER 'hue'@'hadoop' IDENTIFIED BY 'hue';" >> /tmp/init_hue.sql
	echo "CREATE DATABASE hue;" >> /tmp/init_hue.sql
	echo "GRANT ALL ON hue.* TO 'hue'@'%';" >> /tmp/init_hue.sql

	echo "CREATE USER 'hue_sample'@'%' IDENTIFIED BY 'hue_sample';" >> /tmp/init_hue.sql
	echo "CREATE USER 'hue_sample'@'localhost' IDENTIFIED BY 'hue_sample';" >> /tmp/init_hue.sql
	echo "CREATE USER 'hue_sample'@'hadoop' IDENTIFIED BY 'hue_sample';" >> /tmp/init_hue.sql
	echo "CREATE DATABASE hue_sample;" >> /tmp/init_hue.sql
	echo "GRANT ALL ON hue_sample.* TO 'hue_sample'@'%';" >> /tmp/init_hue.sql

	echo "FLUSH PRIVILEGES;" >> /tmp/init_hue.sql
	
	mysql -u root < /tmp/init_hue.sql

	chown -R vagrant:vagrant /opt/hadoop/hue

	cd /opt/hadoop/hue/
	sudo -u vagrant build/env/bin/hue syncdb --noinput
	sudo -u vagrant build/env/bin/hue migrate --noinput
	
	sudo -u vagrant build/env/bin/hue  createsuperuser --username=vagrant --email=vagrant@hadoop.local --noinput

	echo "from django.contrib.auth.models import User" > /tmp/create_hue_user.py 
	echo "a = User.objects.get(username='vagrant')" >> /tmp/create_hue_user.py 
	echo "a.is_staff = True" >> /tmp/create_hue_user.py 
	echo "a.is_superuser = True" >> /tmp/create_hue_user.py 
	echo "a.set_password('vagrant')" >> /tmp/create_hue_user.py 
	echo "a.save()" >> /tmp/create_hue_user.py 

	sudo -u vagrant bash -c 'build/env/bin/hue shell < /tmp/create_hue_user.py'

	# install livy
	download_and_untargz \
		"https://github.com/cloudera/livy/archive/v0.2.0.tar.gz" \
		v0.2.0.tar.gz \
		/opt/hadoop

	ln -s /opt/hadoop/livy-0.2.0/ /opt/hadoop/livy

	cd /opt/hadoop/livy
	mvn -Dspark.version=1.6.1 package -Dmaven.test.skip=true

	cat $DIR/conf/hue/livy.conf > /opt/hadoop/livy/conf/livy.conf

	chown -R vagrant:vagrant /opt/hadoop/livy-0.2.0/

	start_hue
}


function install_drill {
	# drill
	download_and_untargz \
		"http://getdrill.org/drill/download/apache-drill-1.1.0.tar.gz" \
		apache-drill-1.1.0.tar.gz \
		/opt/hadoop

	cd /opt/hadoop/apache-drill-1.1.0

	cat $DIR/conf/drill/drill-env.sh > conf/drill-env.sh

	cat $DIR/conf/drill/drill-override.conf > conf/drill-override.conf

	bin/drillbit.sh start
}


function start_kylin {
	chmod +x $DIR/start-kylin.sh
	sudo -u vagrant $DIR/start-kylin.sh
}

function install_kylin {

	if [ -d /opt/hadoop/apache-kylin-1.5.2.1-bin ]; then
		start_kylin
		return
	fi

	echo "install kylin"

	download_and_untargz \
		"https://dist.apache.org/repos/dist/release/kylin/apache-kylin-1.5.2.1/apache-kylin-1.5.2.1-HBase1.x-bin.tar.gz" \
		apache-kylin-1.5.2.1-HBase1.x-bin.tar.gz \
		/opt/hadoop
	
	ln -s /opt/hadoop/apache-kylin-1.5.2.1-bin/ /opt/hadoop/kylin

	echo 'export KYLIN_HOME=/opt/hadoop/kylin' >> /etc/bashrc
	echo 'export PATH=$PATH:$KYLIN_HOME/bin' >> /etc/bashrc
	source /etc/bashrc

	cd $KYLIN_HOME
	chown -R vagrant:vagrant /opt/hadoop/apache-kylin-1.5.2.1-bin/

	start_kylin
}


# could use https://github.com/cogitatio/vagrant-hostsupdater but do it manually
cat $DIR/conf/hosts > /etc/hosts

if [ ! -d /media/data/hadoop ]; then
	mkdir /media/data/hadoop
	ln -s /media/data/hadoop /opt/hadoop
fi

yum install -y -d1 wget
yum install -y -d1 ntp
chkconfig ntpd on
/etc/init.d/ntpd start

#chkconfig iptables off
#service iptables stop
#setenforce 0
#echo "SELINUX=disabled" >  /etc/sysconfig/selinux

install_jdk
install_python
#install_hue
#install_drill
#install_kylin

echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag

# install postgresql for Hive/Ambari
yum install -y -d1 postgresql-server postgresql-jdbc
service postgresql initdb
service postgresql start

echo "CREATE USER hive WITH PASSWORD 'hive';" > /tmp/create_hive_db.sql
echo "CREATE DATABASE hive OWNER hive;" >> /tmp/create_hive_db.sql
sudo -u postgres bash -c "psql < /tmp/create_hive_db.sql"

echo "host  all  hive 0.0.0.0/0 md5" >> /var/lib/pgsql/data/pg_hba.conf
/etc/init.d/postgresql restart

# install ambari
cd /etc/yum.repos.d/
wget -nv http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.2.1.0/ambari.repo

yum install -y -d1 ambari-server ambari-agent

ambari-server setup -j /opt/jdk1.8.0_45/ --silent
ambari-server setup --silent --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar

# install additional Hawq ambari stack
HDB_AMBARI_DOWNLOAD_LOC=https://www.dropbox.com/s/6ik8f3r472f7mzq/hdb-ambari-plugin-2.0.0-448.tar.gz
HDB_DOWNLOAD_LOC=https://www.dropbox.com/s/5rzhqxajbd5pq9k/hdb-2.0.0.0-22126.tar.gz

mkdir -p /tmp/hawqsetup
cd /tmp/hawqsetup

wget -nv ${HDB_DOWNLOAD_LOC}
wget -nv ${HDB_AMBARI_DOWNLOAD_LOC}
tar -xvzf /tmp/hawqsetup/hdb-2.0.0.0-*.tar.gz -C /tmp/hawqsetup
tar -xvzf /tmp/hawqsetup/hdb-ambari-plugin-2.0.0-*.tar.gz -C /tmp/hawqsetup
yum install -y httpd
service httpd start
chkconfig httpd on
cd /tmp/hawqsetup/hdb*
./setup_repo.sh
cd /tmp/hawqsetup/hdb-ambari-plugin*
./setup_repo.sh  
yum install -y -d1 hdb-ambari-plugin

# start ambari
ambari-server start
ambari-agent start

# install Ambari BluePrint
/opt/anaconda/bin/python $DIR/post_ambari.py | tee /tmp/post_ambari.log

# prepare HDFS for user vagrant
sudo -u hdfs hdfs dfs -mkdir -p /user/vagrant/
sudo -u hdfs hdfs dfs -chown -R vagrant /user/vagrant

# prepare Hawq

echo "CREATE DATABASE gpadmin OWNER gpadmin;" > /tmp/create_gpadmin_db.sql
sudo -u gpadmin bash -c "source /usr/local/hawq/greenplum_path.sh; psql -d template1 -p 10432 -h localhost < /tmp/create_gpadmin_db.sql"


# Jupyter
export LC_ALL=C; /opt/anaconda/bin/pip install plotly
sudo -u vagrant mkdir -p /home/vagrant/.ipython/kernels/pyspark/
sudo -u vagrant touch /home/vagrant/.ipython/kernels/pyspark/kernel.json
cat $DIR/conf/jupyter/kernel.json > /home/vagrant/.ipython/kernels/pyspark/kernel.json

#sudo -u vagrant $DIR/samples/run.sh

# to export notebook as pdf
#yum -y -d1 install texlive texlive-latex-extra pandoc texlive-latex 

exit

# tez ui
download_and_untargz \
	"http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.2/bin/apache-tomcat-8.5.2.tar.gz" \
	apache-tomcat-8.5.2.tar.gz \
	/opt/hadoop/tez

mkdir /opt/hadoop/tez/apache-tomcat-8.5.2/webapps/tez-ui
unzip /opt/hadoop/tez/tez-ui-0.7.1.war -d /opt/hadoop/tez/apache-tomcat-8.5.2/webapps/tez-ui
cat $DIR/conf/hadoop/server.xml > /opt/hadoop/tez/apache-tomcat-8.5.2/conf/server.xml
cat $DIR/conf/hadoop/config.js > /opt/hadoop/tez/apache-tomcat-8.5.2/webapps/tez-ui/scripts/config.js




# install Kylin
sudo -u hdfs hdfs dfs -mkdir /kylin
sudo -u hdfs hdfs dfs -chmod 777 /kylin


export HIVE_CONF=/etc/hive/conf
export HCAT_HOME=/usr/hdp/current/hive-webhcat/
#echo "kylin.hive.client=beeline" >> conf/kylin.properties


# install opentsdb
yum install -y -d1 https://github.com/OpenTSDB/opentsdb/releases/download/v2.2.0/opentsdb-2.2.0.noarch.rpm


echo "tsd.storage.hbase.zk_basedir = /hbase-unsecure" >> /etc/opentsdb/opentsdb.conf
env COMPRESSION=NONE HBASE_HOME=/usr/hdp/2.4.2.0-258/hbase/ /usr/share/opentsdb/tools/create_table.sh
/etc/init.d/opentsdb start
sudo chmod a+w /var/log/opentsdb/queries.log
sudo chmod a+w /var/log/opentsdb/opentsdb.log


# install grafana
sudo yum install -y -d1 initscripts fontconfig
sudo yum install -y -d1 https://grafanarel.s3.amazonaws.com/builds/grafana-3.0.4-1464167696.x86_64.rpm
sudo service grafana-server start

