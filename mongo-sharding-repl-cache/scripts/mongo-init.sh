#!/bin/bash

###
# Инициализируем бд
###

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id: "config_server",
    configsvr: true,
    members:[{_id: 0, host: "173.17.0.10:27017"}]
  }
)
exit()
EOF

sleep 1 && docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        {_id: 0, host: "173.17.0.9:27018"},
        {_id: 1, host: "173.17.0.11:27016"},
        {_id: 2, host: "173.17.0.12:27015"}
      ]
    }
)
exit()
EOF

sleep 1 && docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        {_id: 0, host: "173.17.0.8:27019"},
        {_id: 1, host: "173.17.0.14:27014"},
        {_id: 2, host: "173.17.0.13:27013"}
      ]
    }
)
exit()
EOF

sleep 1 && docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/173.17.0.9:27018")
sh.addShard("shard2/173.17.0.8:27019")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
exit()
EOF

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF