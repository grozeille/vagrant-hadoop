source /etc/bashrc

cd /opt/hadoop/hue
build/env/bin/supervisor &
build/env/bin/hue livy_server >> logs/livy.out 2>&1 & 