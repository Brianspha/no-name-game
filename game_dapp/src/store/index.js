import { createStore } from 'vuex'
import * as BigN from "bignumber.js";
import swal from "sweetalert2";

const BigNumber = BigN.BigNumber;
export default createStore({
  state: {
    currentLevel: 10,
    address: "",
    basePoints: 10,
    paused: false,
    player: {},
    currentLevelTime: 40000,
    sizePenalty: 5,
    total: 0,
    incrementCollected: 0,
    speed: 10,
    pausedSpeed: 30,
    score: 0,
    showLeaderBoard: false,
    winnings: [],
    isLoading: false,
    connected: false,
    publicClient: {},
    walletClient: {},
    paymentTokenDetails: {},
    canPlay: true,
    leaderBoard: [],
    chainId: 0,
    prizePool: []

  },
  getters: {
  },
  mutations: {
  },
  actions: {
    async getWinnings(_context, _data) {
      if (!this.state.connected) return;
      try {

        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error getWinnings", error)
        return false
      }
    },
    async getLeaderBoard(_context, _data) {
      if (!this.state.connected) {
        return;
      }
      try {



      } catch (error) {
        console.error("Unable to load leaderboard: ", error)
      }
    },
    async getLatestScores(_context, _data) {
      if (!this.state.connected) return

      try {

        return []
      } catch (error) {
        console.error("error getting latest scores: ", error)
        return []
      }
    },
    async claimWinnings(_context, _data) {
      if (!this.state.connected) return;

      try {
        this.state.isLoading = true

        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error getWinnings", error)

        return false
      }
    },
    async sortScoresAndAddresses(_context, data) {
      let userscores, latestAddresses;
      [userscores, latestAddresses] = data;


      let combined = userscores.map((score, index) => {
        return { score: new BigNumber(score), address: latestAddresses[index] };
      });

      combined.sort((a, b) => b.score.comparedTo(a.score));

      let sortedScores = combined.map(item => item.score.toString());
      let sortedAddresses = combined.map(item => item.address);

      return [
        sortedScores, sortedAddresses
      ];
    },
    async freePlay(_context, _data) {
      if (!this.state.connected) return;

      try {
        this.state.isLoading = true


        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error freePlay", error)
        return false
      }
    },
    async paidPlay(_context, _data) {
      if (!this.state.connected) return;
      try {

        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error paidPlay", error)
        return false
      }
    },
    getPaymentTokenDetails: async function (_context, _data) {
      if (!this.state.connected) return;
      try {
        this.state.isLoading = true;

        this.state.isLoading = false;
      } catch (error) {
        console.error("Unable to load Payment Token Details: ", error);
        this.state.isLoading = false;
        this.dispatch("error", "Unable to load Payment Token Details");
      }
    },
    async checkPaymentTokenApproval(_context, _data) {
      this.state.isLoading = true;

    },
    connectWallet: async function (_context, _data) {
      try {
        if (this.state.connected) {
          this.state.connected = false;
          this.state.address = "";
          return;
        }
        const provider = await detectEthereumProvider();
        if (!provider) return;
        this.state.isLoading = true
        this.state.isLoading = false;
      } catch (error) {
        console.error(error);
        this.state.isLoading = false;
      }
    },
    success(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "success",
        title: "Success",
        showConfirmButton: false,
        timer: 2500,
        text: message,
      });
    },
    async switchToSepolia() {
      try {
        await ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: import.meta.env.VITE_APP_CHAINID }],
        });
      } catch (switchError) {
        if (switchError.code === 4902) {
          console.log("Sepolia Testnet hasn't been added to the wallet!");
          await this.dispatch("addNetwork");
        }
      }
    },
    setupListeners: async function (_context, _data) {
      const chainId = await window.ethereum.request({ method: "eth_chainId" });
      if (chainId != import.meta.env.VITE_APP_CHAINID) {
        await this.dispatch("switchToSepolia");
      }
      window.ethereum.on("chainChanged", async (_chainId) => {
        window.location.reload();
      });
      window.ethereum.on("accountsChanged", async (accounts) => {
        window.location.reload();
      });
    },
    async addNetwork() {
      try {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            {
              chainId: import.meta.env.VITE_APP_CHAINID,
              rpcUrls: [import.meta.env.VITE_RPC_URL],
              chainName: import.meta.env.VITE_RPC_NAME,
              nativeCurrency: {
                name: import.meta.env.VITE_RPC_CURRENCY,
                symbol: import.meta.env.VITE_RPC_SYMBOL,
                decimals: import.meta.env.VITE_RPC_DECIMALS,
              },
              blockExplorerUrls: ["https://sepolia.etherscan.io/"],
            },
          ],
        });
      } catch (error) {
        console.error("error adding chain", error);
      }
    },
    async addPlayTokenToWallet(_context, _data) {

      try {
        // wasAdded is a boolean. Like any RPC method, an error may be thrown.
        const wasAdded = await window.ethereum.request({
          method: 'wallet_watchAsset',
          params: {
            type: 'ERC20', // Initially only supports ERC20, but eventually more!
            options: {
              address: addresses.Token, // The address that the token is at.
              symbol: this.state.paymentTokenDetails.symbol, // A ticker symbol or shorthand, up to 5 chars.
              decimals: this.state.paymentTokenDetails.decimals, // The number of decimals in the token
              image: "https://cdn3.iconfinder.com/data/icons/meteocons/512/n-a-512.png", // A string url of the token logo
            },
          },
        });

        if (wasAdded) {
          this.dispatch("success", "Play token was added successfully")
        } else {
          this.dispatch("warning", "To play the game and track rewards please add the play toke manually")
        }
      } catch (error) {
        console.log(error);
      }
    },
    successWithCallBack(_context, message) {
      swal
        .fire({
          position: "top-end",
          icon: "success",
          title: "Success",
          showConfirmButton: true,
          text: message.message,
        })
        .then((results) => {
          if (results.isConfirmed) {
            message.onTap();
          }
        });
    },
    warning(_context, message) {
      swal.fire("Warning", message.warning, "warning").then((result) => {
        if (result.isConfirmed) {
          message.onTap();
        }
      });
    },
    toastError(_context, message) {
      toast.error(message);
    },
    toastWarning(_context, message) {
      toast.warning(message);
    },
    toastSuccess(_context, message) {
      toast.success(message);
    },
    error(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "error",
        title: "Error!",
        showConfirmButton: false,
        timer: 2500,
        text: message,
      });
    },
    successWithFooter(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "success",
        title: "Success",
        text: message.message,
        footer: `<a href=https://sepolia.etherscan.io/txs/${message.txHash}> View on Sepolia scan</a>`,
      });
    },
    errorWithFooterMetamask(_context, message) {
      swal.fire({
        icon: "error",
        title: "Error!",
        text: message,
        footer: `<a href= https://metamask.io> Download Metamask</a>`,
      });
    },
  },
  modules: {
  }
})
