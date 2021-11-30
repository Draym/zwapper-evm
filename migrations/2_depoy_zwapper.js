const Zwapper = artifacts.require('Zwapper')

module.exports = async function (deployer, network, accounts) {
    // Deploy Mock Zwapper
    await deployer.deploy(Zwapper)
};
