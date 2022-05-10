const Zwapper = artifacts.require('Zwapper')

module.exports = async function (deployer, network, accounts) {
    // Deploy Zwapper
    await deployer.deploy(Zwapper)
};
