```Shell
docker network create mongoCluster
```

```Shell
docker run -d --rm -p 27017:27017 --name mongo1 --network mongoCluster mongodb/mongodb-community-server:6.0.6-ubi8 --replSet rs0 --bind_ip localhost,mongo1
docker run -d --rm -p 27018:27017 --name mongo2 --network mongoCluster mongodb/mongodb-community-server:6.0.6-ubi8 --replSet rs0 --bind_ip localhost,mongo2
docker run -d --rm -p 27019:27017 --name mongo3 --network mongoCluster mongodb/mongodb-community-server:6.0.6-ubi8 --replSet rs0 --bind_ip localhost,mongo3
```

```PowerShell
docker exec -it mongo1 mongosh
```

```Shell
rs.initiate({ _id: "rs0", members: [ {_id: 0, host: "mongo1"}, {_id: 1, host: "mongo2"}, {_id: 2, host: "mongo3"} ] })
```