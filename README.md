<p align="center">
  <h1 align="center">🪙🍪 SugarDollar 🍪🪙</h1>
  <h3 align="center">A sweet algorithmic stablecoin backed by DAI & CKIE</h3>
</p>

### Brief Summary

sUSD (Sugar Dollar) is a stablecoin backed partially by DAI, this means that you will need DAI & CKIE to mint sUSD.
The rate of DAI & CKIE to create sUSD will be determined by the **Collateral Policy**.
To mint 1 sUSD you will have to deposit a total value off DAI & CKIE.

---

#### How does the mint sUSD process work?
Lets imagine that the Target Collateral Ratio given by the Collateral Policy is 90%, this means that you need 0.9 USD in DAI and 0.1 USD in CKIE to mint 1 sUSD.
For simplification lets imagine that CKIE price is 1 USD, and 1 DAI is 1 USD. So you just give 0.9 USD in DAI and 0.1 USD in CKIE to mint 1 sUSD. Then the mint function will transfer 0.9 DAI to the **bank vault** and **burn** 0.1 CKIE.
Finally you will receive 0.997 sUSD, because there is a 0.3% fee (0.003 sUSD) and will go the vault to help ud mantein the system.

#### How does the redeem sUSD process work?
When you redeem sUSD you will get a total value of 1 USD in a mix of DAI & CKIE.
For example, lets redeem 1 sUSD, then the redeem function will burn 1 sUSD, there is a 0.3% fee, that will be burned.
The ratio of DAI will be determine by the balance of DAI in the vault divided by total supply of sUSD, lets say that balance of vault is 20 DAI and total sUSD supply is 40, then the ratio is 50%, this means that for every 2 sUSD there is 1 DAI.
For simplification lets imagine that CKIE price is 1 USD, and 1 DAI is 1 USD. 
So in this case 1 sUSD from your wallet will be burned, 0.5 DAI from the vault will be transfer to your wallet and 0,497 CKIE will be minted to your wallet. You will receive a total value of 0.997 USD


#### How does the sUSD price is mantein?
Via arbitrage. For example, when the price of sUSD goes above $1, it becomes advantageous to mint sUSD using DAI & CKIE, and then sell the sUSD on the open market. If the price falls below $1, then it is advantageous to buy sUSD and redeem for DAI & CKIE, which can be used to buy more sUSD on the market.


#### How does the Collateral Policy works?

Its just a percentage in a range between 100% and 75%, that indicates the amount of USD in DAI needed to mint sUSD.
This ratio will start in 100%, and every 10 minutes will;
- decrease 0.25%: if the price of sUSD in USD is greater than 1.005 USD
- increase 0.25%: if the price of sUSD in USD is lower than 0.995 USD




---

### Deployed contracts

- 10 minutes TWAP oracle CKIE-WMATIC<br />
[0xE42d5A242bDcc9E116894fCC8aD67e253574068E](https://polygonscan.com/address/0xE42d5A242bDcc9E116894fCC8aD67e253574068E)
- 10 minutes TWAP oracle SUSD-DAI<br />
[0x81372682B25823211d822E1C174e04493246Bb2d](https://polygonscan.com/address/0x81372682B25823211d822E1C174e04493246Bb2d)
- Multi Oracle<br />
[0xD13cCE7F76318eDC9584A6b1c9729776bA67fD84](https://polygonscan.com/address/0xD13cCE7F76318eDC9584A6b1c9729776bA67fD84)
- Collateral Policy<br />
[0x08e3b015Db5C0Be1489cb170dA0D27cdd545607E](https://polygonscan.com/address/0x08e3b015Db5C0Be1489cb170dA0D27cdd545607E)
