#!/bin/bash
set -e

if [[ `uname` == 'Darwin' ]]; then
    echo "Mac OS"
    export PATH=${PWD}/darwin-amd64-1.4.12/bin:$PATH
fi
if [[ `uname` == 'Linux' ]]; then
    echo "Linux"
    export PATH=${PWD}/linux-amd64-1.4.12/bin:$PATH
fi

echo "一、清理环境"
./stop.sh

echo "二、生成证书和秘钥（ MSP 材料），生成结果将保存在 crypto-config 文件夹中"
cryptogen generate --config=./crypto-config.yaml

export CA_PRIVATE_KEY=$(cd crypto-config/peerOrganizations/org1.com/ca && ls *_sk)

echo "三、创建排序通道创世区块"
configtxgen -profile FiveOrgsOrdererGenesis -outputBlock ./config/genesis.block -channelID firstchannel

echo "四、生成通道配置事务'appchannel.tx'"
configtxgen -profile FiveOrgsChannel -outputCreateChannelTx ./config/appchannel.tx -channelID appchannel

echo "五、为 五个节点组织 定义锚节点"
configtxgen -profile FiveOrgsChannel -outputAnchorPeersUpdate ./config/Org1Anchor.tx -channelID appchannel -asOrg Org1
configtxgen -profile FiveOrgsChannel -outputAnchorPeersUpdate ./config/Org2Anchor.tx -channelID appchannel -asOrg Org2
configtxgen -profile FiveOrgsChannel -outputAnchorPeersUpdate ./config/Org3Anchor.tx -channelID appchannel -asOrg Org3
configtxgen -profile FiveOrgsChannel -outputAnchorPeersUpdate ./config/Org4Anchor.tx -channelID appchannel -asOrg Org4
configtxgen -profile FiveOrgsChannel -outputAnchorPeersUpdate ./config/Org5Anchor.tx -channelID appchannel -asOrg Org5

echo "区块链 ： 启动"
docker-compose up -d
echo "正在等待节点的启动完成，等待5秒"
sleep 5

Org1Peer="CORE_PEER_ADDRESS=peer0.org1.com:7051 CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/org1.com/users/Admin@org1.com/msp"
Org2Peer="CORE_PEER_ADDRESS=peer0.org2.com:7051 CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/org2.com/users/Admin@org2.com/msp"
Org3Peer="CORE_PEER_ADDRESS=peer0.org3.com:7051 CORE_PEER_LOCALMSPID=Org3MSP CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/org3.com/users/Admin@org3.com/msp"
Org4Peer="CORE_PEER_ADDRESS=peer0.org4.com:7051 CORE_PEER_LOCALMSPID=Org4MSP CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/org4.com/users/Admin@org4.com/msp"
Org5Peer="CORE_PEER_ADDRESS=peer0.org5.com:7051 CORE_PEER_LOCALMSPID=Org5MSP CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/org5.com/users/Admin@org5.com/msp"

echo "六、创建通道"
docker exec cli bash -c "$Org1Peer peer channel create -o orderer.trace.com:7050 -c appchannel -f /etc/hyperledger/config/appchannel.tx"

echo "七、将所有节点加入通道"
docker exec cli bash -c "$Org1Peer peer channel join -b appchannel.block"
docker exec cli bash -c "$Org2Peer peer channel join -b appchannel.block"
docker exec cli bash -c "$Org3Peer peer channel join -b appchannel.block"
docker exec cli bash -c "$Org4Peer peer channel join -b appchannel.block"
docker exec cli bash -c "$Org5Peer peer channel join -b appchannel.block"

echo "八、更新锚节点"
docker exec cli bash -c "$Org1Peer peer channel update -o orderer.trace.com:7050 -c appchannel -f /etc/hyperledger/config/Org1Anchor.tx"
docker exec cli bash -c "$Org2Peer peer channel update -o orderer.trace.com:7050 -c appchannel -f /etc/hyperledger/config/Org2Anchor.tx"
docker exec cli bash -c "$Org3Peer peer channel update -o orderer.trace.com:7050 -c appchannel -f /etc/hyperledger/config/Org3Anchor.tx"
docker exec cli bash -c "$Org4Peer peer channel update -o orderer.trace.com:7050 -c appchannel -f /etc/hyperledger/config/Org4Anchor.tx"
docker exec cli bash -c "$Org5Peer peer channel update -o orderer.trace.com:7050 -c appchannel -f /etc/hyperledger/config/Org5Anchor.tx"

# -n 链码名，可以自己随便设置
# -v 版本号
# -p 链码目录，在 /opt/gopath/src/ 目录下
echo "九、安装链码"
docker exec cli bash -c "$Org1Peer peer chaincode install -n trace -v 1.0.0 -l node -p /opt/gopath/src/chaincode"
docker exec cli bash -c "$Org2Peer peer chaincode install -n trace -v 1.0.0 -l node -p /opt/gopath/src/chaincode"
docker exec cli bash -c "$Org3Peer peer chaincode install -n trace -v 1.0.0 -l node -p /opt/gopath/src/chaincode"
docker exec cli bash -c "$Org4Peer peer chaincode install -n trace -v 1.0.0 -l node -p /opt/gopath/src/chaincode"
docker exec cli bash -c "$Org5Peer peer chaincode install -n trace -v 1.0.0 -l node -p /opt/gopath/src/chaincode"

# 只需要其中一个节点实例化
# -n 对应上一步安装链码的名字
# -v 版本号
# -C 是通道，在fabric的世界，一个通道就是一条不同的链
# -c 为传参，传入init参数
echo "十、实例化链码"
docker exec cli bash -c "$Org1Peer peer chaincode instantiate -o orderer.trace.com:7050 -C appchannel -n trace -l node -v 1.0.0 -c '{\"Args\":[\"initLedger\"]}' -P \"AND ('Org1MSP.member','Org2MSP.member')\""

echo "正在等待链码实例化完成，等待5秒"
sleep 5

# 进行链码交互，验证链码是否正确安装及区块链网络能否正常工作
echo "十一、验证链码"
docker exec cli bash -c "$Org1Peer peer chaincode invoke -C appchannel -n trace -c '{\"Args\":[\"queryAllCars\"]}'"