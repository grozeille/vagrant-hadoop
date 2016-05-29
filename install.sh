#!/bin/bash -x
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
		exit
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
	alternatives --set jar /opt/jdk1.8.0_45/bin/jar
	alternatives --set javac /opt/jdk1.8.0_45/bin/javac

	echo 'export JAVA_HOME=/opt/jdk1.8.0_45' >> /etc/bashrc
	echo 'export JRE_HOME=/opt/jdk1.8.0_45/jre' >> /etc/bashrc
	echo 'export PATH=$PATH:/opt/jdk1.8.0_45/bin:/opt/jdk1.8.0_45/jre/bin' >> /etc/bashrc

	source /etc/bashrc
	
}

function install_mysql {
	if [ -d /usr/bin/mysql ]; then
		exit
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

function install_hadoop {
	if [ -d /opt/hadoop/hadoop-2.6.0 ]; then
		exit
	fi
	echo "install hadoop"

	# install hadoop
	chmod +x $DIR/setup-ssh.sh
	sudo -u vagrant $DIR/setup-ssh.sh

	sysctl -w vm.swappiness=0 

	download_and_untargz \
		"https://archive.apache.org/dist/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz" \
		hadoop-2.6.0.tar.gz \
		/opt/hadoop

	ln -s /opt/hadoop/hadoop-2.6.0/ /opt/hadoop/hadoop

	download_and_untargz \
		"https://archive.apache.org/dist/tez/0.7.1/apache-tez-0.7.1-bin.tar.gz" \
		apache-tez-0.7.1-bin.tar.gz \
		/opt/hadoop

	ln -s /opt/hadoop/apache-tez-0.7.1-bin/ /opt/hadoop/tez

	# tez ui
	download_and_untargz \
		"http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.2/bin/apache-tomcat-8.5.2.tar.gz" \
		apache-tomcat-8.5.2.tar.gz \
		/opt/hadoop/tez

	mkdir /opt/hadoop/tez/apache-tomcat-8.5.2/webapps/tez-ui
	unzip /opt/hadoop/tez/tez-ui-0.7.1.war -d /opt/hadoop/tez/apache-tomcat-8.5.2/webapps/tez-ui
	cat $DIR/conf/hadoop/server.xml > /opt/hadoop/tez/apache-tomcat-8.5.2/conf/server.xml
	cat $DIR/conf/hadoop/config.js > /opt/hadoop/tez/apache-tomcat-8.5.2/webapps/tez-ui/scripts/config.js


	echo 'export HADOOP_HOME=/opt/hadoop/hadoop' >> /etc/bashrc
	echo 'export PATH=$PATH:/opt/hadoop/hadoop/bin' >> /etc/bashrc
	echo 'export HADOOP_CONF_DIR=/opt/hadoop/hadoop/etc/hadoop' >> /etc/bashrc
	echo 'export TEZ_HOME=/opt/hadoop/tez' >> /etc/bashrc
	source /etc/bashrc

	mkdir /opt/hadoop/data
	chmod a+w /opt/hadoop/data

	cat $DIR/conf/hadoop/hdfs-site.xml > $HADOOP_HOME/etc/hadoop/hdfs-site.xml

	cat $DIR/conf/hadoop/core-site.xml > $HADOOP_HOME/etc/hadoop/core-site.xml

	cat $DIR/conf/hadoop/hadoop-env.sh > $HADOOP_HOME/etc/hadoop/hadoop-env.sh

	cat $DIR/conf/hadoop/httpfs-site.xml > $HADOOP_HOME/etc/hadoop/httpfs-site.xml

	cat $DIR/conf/hadoop/yarn-site.xml > $HADOOP_HOME/etc/hadoop/yarn-site.xml

	cat $DIR/conf/hadoop/mapred-site.xml > $HADOOP_HOME/etc/hadoop/mapred-site.xml

	mkdir $TEZ_HOME/conf
	cat $DIR/conf/hadoop/tez-site.xml > $TEZ_HOME/conf/tez-site.xml

	chown -R vagrant:vagrant /opt/hadoop/hadoop-2.6.0/
	chown -R vagrant:vagrant /opt/hadoop/apache-tez-0.7.1-bin/
	chown -R vagrant:vagrant /opt/hadoop/apache-tomcat-8.5.2/

	chmod +x $DIR/start-hadoop.sh
	sudo -u vagrant $DIR/start-hadoop.sh
}

function install_hue {
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
	make apps
	make install PREFIX=/opt/hadoop

	cat $DIR/conf/hue/hue.ini > /opt/hadoop/hue/desktop/conf/hue.ini

	# configure mysql
	echo "CREATE USER 'hue'@'%' IDENTIFIED BY 'hue';" > /tmp/init_hue.sql
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

	chmod +x $DIR/start-hue.sh
	sudo -u vagrant $DIR/start-hue.sh
}

function install_spark {
	# spark
	download_and_untargz \
		"http://archive.apache.org/dist/spark/spark-1.6.1/spark-1.6.1-bin-hadoop2.6.tgz" \
		spark-1.6.1-bin-hadoop2.6.tgz \
		/opt/hadoop

	ln -s /opt/hadoop/spark-1.6.1-bin-hadoop2.6/ /opt/hadoop/spark

	echo 'export SPARK_HOME=/opt/hadoop/spark' >> /etc/bashrc
	echo 'export PATH=$PATH:$SPARK_HOME/bin' >> /etc/bashrc
	echo 'export PYSPARK_PYTHON=$PYTHON_HOME/bin/python' >> /etc/bashrc
	echo 'export PYTHONPATH="$SPARK_HOME/python/:$PYTHONPATH"' >> /etc/bashrc
	echo 'export PYTHONPATH="$SPARK_HOME/python/lib/py4j-0.9-src.zip:$PYTHONPATH"' >> /etc/bashrc
	source /etc/bashrc

	cat $DIR/conf/spark/spark-env.sh > $SPARK_HOME/conf/spark-env.sh

	if [ -z "$HIVE_HOME" ]; then
		cat $DIR/conf/spark/hive-site.xml > $SPARK_HOME/conf/hive-site.xml
	fi

	chown -R vagrant:vagrant /opt/hadoop/spark-1.6.1-bin-hadoop2.6/
}

function install_hive {
	if [ -d /opt/hadoop/apache-hive-1.2.1-bin ]; then
		exit
	fi

	echo "CREATE USER 'hive'@'%' IDENTIFIED BY 'hive';" > /tmp/init_hive.sql
	echo "CREATE USER 'hive'@'localhost' IDENTIFIED BY 'hive';" >> /tmp/init_hive.sql
	echo "CREATE USER 'hive'@'hadoop' IDENTIFIED BY 'hive';" >> /tmp/init_hive.sql
	echo "CREATE DATABASE hive;" >> /tmp/init_hive.sql
	echo "GRANT ALL ON hive.* TO 'hive'@'%';" >> /tmp/init_hive.sql
	echo "FLUSH PRIVILEGES;" >> /tmp/init_hive.sql
	
	mysql -u root < /tmp/init_hive.sql

	# install hive

	download_and_untargz \
		"https://archive.apache.org/dist/hive/hive-1.2.1/apache-hive-1.2.1-bin.tar.gz" \
		apache-hive-1.2.1-bin.tar.gz \
		/opt/hadoop

	ln -s /opt/hadoop/apache-hive-1.2.1-bin/ /opt/hadoop/hive
	
	download_and_untargz \
		"http://cdn.mysql.com/Downloads/Connector-J/mysql-connector-java-5.0.8.tar.gz" \
		mysql-connector-java-5.0.8.tar.gz \
		/opt/hadoop
	cp /opt/hadoop/mysql-connector-java-5.0.8/mysql-connector-java-5.0.8-bin.jar /opt/hadoop/apache-hive-1.2.1-bin/lib/

	echo 'export HIVE_HOME=/opt/hadoop/hive/' >> /etc/bashrc
	echo 'export PATH=$PATH:$HIVE_HOME/bin' >> /etc/bashrc
	source /etc/bashrc

	cat $DIR/conf/hive/hive-site.xml > $HIVE_HOME/conf/hive-site.xml

	cd $HIVE_HOME
	mkdir logs
	chown -R vagrant:vagrant /opt/hadoop/apache-hive-1.2.1-bin
	chmod +x $DIR/start-hive.sh
	sudo -u vagrant $DIR/start-hive.sh
}

function install_zookeeper {
	# zookeeper
	download_and_untargz \
		"https://archive.apache.org/dist/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz" \
		zookeeper-3.4.6.tar.gz \
		/opt/hadoop

	cd /opt/hadoop/zookeeper-3.4.6

	mkdir data

	cat $DIR/conf/zookeeper/zoo.cfg > conf/zoo.cfg
	echo '1' > data/myid

	bin/zkServer.sh start
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

function install_hbase {
	download_and_untargz \
		"http://archive.apache.org/dist/hbase/1.1.2/hbase-1.1.2-bin.tar.gz" \
		hbase-1.1.2-bin.tar.gz \
		/opt/hadoop
}


# could use https://github.com/cogitatio/vagrant-hostsupdater but do it manually
cat $DIR/conf/hosts > /etc/hosts

if [ ! -d /media/data/hadoop ]; then
	mkdir /media/data/hadoop
	ln -s /media/data/hadoop /opt/hadoop
fi

yum install -y -d1 wget

install_jdk
install_hadoop
install_mysql
install_hive
install_python
install_spark
install_hue
#install_zookeeper
#install_drill
#install_hbase

# add samples
sudo -u vagrant $DIR/samples/run.sh