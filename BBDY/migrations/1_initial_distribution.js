/*
 * @Descripttion:
 * @version: 1.0
 * @Author: 72
 * @Date: 2024-01-07 16:29:48
 * @LastEditors: 72
 * @LastEditTime: 2024-01-07 18:05:13
 * @Company: 72
 */
const DistributionERC20 = artifacts.require('DistributionERC20')
const { ethers } = require('ethers')
module.exports = function (deployer) {
  deployer.deploy(
    DistributionERC20,
    String(ethers.utils.parseEther('3000000000')),
    'bbdy coin',
    'BBDY'
  )
}
