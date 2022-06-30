- 目录介绍
  - chaincode：为官网提供的fabcar合约、用js编写的
  - network：区块链网络，所有网络、节点生产脚本都在此文件夹内
  - node：通过node sdk连接区块链网络，访问区块内的数据

- 在根目录赋予最高权限

  ```shel
  chmod -R 777 .
  ```

- 启动网络

  ```shell
  cd network
  ./start.sh
  ```

- 关闭网络清理一切产物

  ```shell
  cd network
  ./stop.sh
  ```

- 启动测试数据

  ```shell
  cd node && npm i
  # npm慢的话可以用国内源cnpm  cd node && cnpm i
  
  # 登记管理员账户
  node enrollAdmin
  # 使用管理员生成user1用户
  node registerUser
  # 查询合约内的所有汽车 queryAllCars
  node query
  ```

  


