/*
 * @Descripttion:测试
 * @version: 1.0
 * @Author: LianSP
 * @Date: 2024-01-07 10:29:04
 * @LastEditors: LianSP
 * @LastEditTime: 2024-01-07 21:34:16
 * @Company: 72
 */
const DistributionERC20 = artifacts.require('DistributionERC20')

const { ethers } = require('ethers')
const { expect } = require('chai')

contract('DistributionERC20', async (accounts) => {
  it('deploy', async () => {
    const DERC20Instance = await DistributionERC20.deployed()
  })
  it('test setOrganization', async () => {
    const DERC20Instance = await DistributionERC20.deployed()
    //部署地址不能非机构地址
    await DERC20Instance.setOrganization(
      2,
      [accounts[1], accounts[2]],
      [
        String(ethers.utils.parseEther('10000000')),
        String(ethers.utils.parseEther('5000000')),
      ]
    )
    await DERC20Instance.setOrganization(
      2,
      [accounts[3]],
      [String(ethers.utils.parseEther('5000000'))]
    )
    let aaa = await DERC20Instance.lockNum(accounts[1])
    console.log('aaaaa', String(aaa))
    let ccc = await DERC20Instance.test(accounts[3])
    console.log('ccc', String(ccc))
    let ggg = await DERC20Instance.testA()
    console.log('ggg', String(ggg))
    //设置开始时间
    await DERC20Instance.setStartTime(Date.now().toString().substring(0, 10))
    let eee = await DERC20Instance.lockNum(accounts[3])
    console.log('eee', String(eee))
    let fff = await DERC20Instance.test(accounts[3])
    console.log('fff', String(fff))
    let hhh = await DERC20Instance.testA()
    console.log('hhh', String(hhh))
  })
})
