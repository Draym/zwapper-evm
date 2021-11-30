
require('chai')
    .use(require('chai-as-promised'))
    .should()
const truffleAssert = require('truffle-assertions');


contract('Zwapper', ([owner, player1Address, player2Address]) => {

    beforeEach(async () => {
        console.log("- NEW CONTRACT -")
    })

    afterEach(async () => {
    });

    describe('Zwapper deployment', async () => {
        it('Zwapper setup', async () => {
        })
    })
})