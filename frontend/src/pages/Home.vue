<script lang="ts" setup>
import Navbar from "../components/Navbar.vue";
import { Jazzicon } from "vue-connect-wallet";
import { useStore } from "../store/useStore";
import { storeToRefs } from "pinia";
import { ethers } from "ethers";
import { formatEther, parseEther, parseUnits } from "ethers/lib/utils";
import { onMounted, reactive, watch, computed, ref } from "vue";
import Token from "../abis/Token.json";
import LoanShark from "../abis/LoanSharkToken.json";

const { address } = storeToRefs(useStore());

const provider = new ethers.providers.Web3Provider(window.ethereum);

const balances = reactive({
  token: 0,
  collateralToken: 0,
  allowance0: 0, // Stablecoin allowance
  allowance1: 0, // Collateral Token allowance
  borrowed: 0, // Currently borrowed amount
});

const contractDetails = reactive({
  address: null as string | null,
  token: 0,
  collateralToken: 0,
  ratio: null as number | null,
  fee: null as number | null,
  owner: null as string | null,
  collectedFees: null as number | null,
});

// Token Details
const tokenDetails = reactive({
  name: null as string | null,
  symbol: null as string | null,
  address: null as string | null,
  decimals: null as number | null,
});

const collateralTokenDetails = reactive({
  name: null as string | null,
  symbol: null as string | null,
  address: null as string | null,
  decimals: null as number | null,
});

const tokenAmount1 = ref(null as number | null);
const tokenAmount2 = ref(null as number | null);

const collateralAmount = computed(() => {
  if (!contractDetails.ratio || !tokenAmount1.value) return 0;
  return (tokenAmount1.value / contractDetails.ratio).toFixed(18);
});

const collateralAmountRepay = computed(() => {
  if (!contractDetails.ratio || !tokenAmount2.value) return 0;
  return (
    tokenAmount2.value / contractDetails.ratio -
    (contractDetails.fee ?? 0)
  ).toFixed(18);
});

let token: any = null;
let collateralToken: any = null;
let loanshark: any = null;

onMounted(init);
watch(address, init);

async function init() {
  if (!address.value) return;

  // Get loan shark contract
  loanshark = new ethers.Contract(
    LoanShark.address,
    LoanShark.abi,
    provider.getSigner()
  );
  contractDetails.address = LoanShark.address;
  contractDetails.owner = await loanshark.owner();

  // Admin information
  if (
    contractDetails.owner &&
    contractDetails.owner.toLowerCase() === address.value.toLowerCase()
  ) {
    contractDetails.collectedFees = +formatEther(
      await loanshark.collectedFees()
    );
  }

  const tokenAddress = await loanshark.stablecoin();
  const collateralTokenAddress = await loanshark.collateralToken();

  // Get stablecoin token contract
  token = new ethers.Contract(tokenAddress, Token.abi, provider.getSigner());
  tokenDetails.address = tokenAddress;
  tokenDetails.name = await token.name();
  tokenDetails.symbol = await token.symbol();
  tokenDetails.decimals = await token.decimals();

  // Get Collateral token contract
  collateralToken = new ethers.Contract(
    collateralTokenAddress,
    Token.abi,
    provider.getSigner()
  );
  collateralTokenDetails.address = collateralTokenAddress;
  collateralTokenDetails.name = await collateralToken.name();
  collateralTokenDetails.symbol = await collateralToken.symbol();
  collateralTokenDetails.decimals = await collateralToken.decimals();

  getBalances();
  getLoanSharkDetails();
  getAllowance();
}

async function getBalances() {
  if (!address.value) return;

  // Get User's Stablecoin Token and Collateral Token balance
  balances.token = +formatEther(await token.balanceOf(address.value));
  balances.collateralToken = +formatEther(
    await collateralToken.balanceOf(address.value)
  );

  // Get Contract's ETH and Token balance
  contractDetails.token = +formatEther(
    await token.balanceOf(LoanShark.address)
  );
  contractDetails.collateralToken = +formatEther(
    await collateralToken.balanceOf(LoanShark.address)
  );

  // Get user's current borrowed amount
  balances.borrowed = +formatEther(await loanshark.borrowed(address.value));
}

async function getLoanSharkDetails() {
  if (!loanshark) return;
  contractDetails.ratio = +formatEther(await loanshark.ratio());
  contractDetails.fee = +formatEther(await loanshark.fee());
}

async function getAllowance() {
  balances.allowance0 = +formatEther(
    await token.allowance(address.value, contractDetails.address)
  );

  balances.allowance1 = +formatEther(
    await collateralToken.allowance(address.value, contractDetails.address)
  );
}

// Stablecoin approve
async function approve0() {
  if (!contractDetails.address) return;
  const result = await token.approve(
    contractDetails.address,
    ethers.constants.MaxUint256
  );
  await result.wait(1);
  getAllowance();
}

// Collateral Token approve
async function approve1() {
  if (!contractDetails.address) return;
  const result = await collateralToken.approve(
    contractDetails.address,
    ethers.constants.MaxUint256
  );
  await result.wait(1);
  getAllowance();
}

async function borrow() {
  if (!tokenAmount1.value || !collateralTokenDetails.decimals) return;
  const result = await loanshark.borrow(
    parseUnits(
      collateralAmount.value.toString(),
      collateralTokenDetails.decimals
    )
  );
  await result.wait(1);
  init();
}

async function repay() {
  if (!tokenAmount2.value) return;
  const result = await loanshark.repay(
    parseEther(tokenAmount2.value.toString())
  );
  await result.wait(1);
  init();
}

// Admin functions
async function claimFees() {
  const result = await loanshark.claimFees();
  await result.wait(1);
  init();
}

async function setFees() {
//   const result = await loanshark.claimFees();
//   await result.wait(1);
//   init();
}
</script>

<template>
  <div class="pb-15">
    <Navbar />
    <div v-if="!address" class="mx-auto mt-10 w-11/12 md:w-1/2">
      <h1>Please connect your wallet to use this Dapp</h1>
    </div>
    <div v-else class="mt-10 mx-auto w-11/12 md:w-1/2">
      <div
        v-if="
          contractDetails.owner &&
          contractDetails.owner.toLowerCase() === address.toLowerCase()
        "
        class="border rounded-lg p-5 bg-blue-100/30"
      >
        <h1 class="font-bold">LoanShark Admin</h1>
        <hr class="my-2" />
        <div class="grid grid-cols-2">
          <div>
            <h1 class="text-sm">Collected Fees</h1>
            <p class="font-semibold text-2xl">
              {{ contractDetails.collectedFees }}
              {{ collateralTokenDetails.symbol }}
            </p>
            <button
              @click="claimFees"
              class="rounded-lg bg-blue-500 px-3 py-2 mt-2 text-white text-sm"
            >
              Claim Fees
            </button>
          </div>
          <div>
            <h1 class="text-sm">Fees</h1>
            <p class="font-semibold text-2xl">
              {{ contractDetails.fee }} {{ collateralTokenDetails.symbol }}
            </p>
            <input type="number" class="p-2 rounded mr-2 border">
            <button
              @click="setFees"
              class="rounded-lg bg-blue-500 px-3 py-2 mt-2 text-white text-sm"
            >
              Set fees
            </button>
          </div>
        </div>
      </div>
      <div class="mt-5 border rounded-lg p-5">
        <h1 class="flex space-x-2 items-center text-sm font-medium">
          <Jazzicon :diameter="40" :address="address" class="mt-1" /><span>
            <div>
              <h1 class="text-sm font-bold">You</h1>
              <h2 class="text-xs text-gray-500">
                {{ address }}
              </h2>
            </div>
          </span>
        </h1>
        <h1 class="font-bold mt-2">
          {{ collateralTokenDetails.name }} Balance
        </h1>
        <p>
          {{ balances.collateralToken }} {{ collateralTokenDetails.symbol }}
        </p>
        <h1 class="font-bold mt-2">{{ tokenDetails.name }} Balance</h1>
        <p>{{ balances.token }} {{ tokenDetails.symbol }}</p>
        <h1 class="font-bold mt-2">Currently borrowed</h1>
        <p>{{ balances.borrowed }} {{ tokenDetails.symbol }}</p>
      </div>
      <div class="mt-5 border rounded-lg p-5">
        <div class="flex space-x-2 items-center">
          <Jazzicon
            :diameter="40"
            :address="contractDetails.address"
            class="mt-1.5"
          />
          <div>
            <h1 class="text-sm font-bold">LoanShark Contract</h1>
            <h2 class="text-xs text-gray-500">{{ contractDetails.address }}</h2>
          </div>
        </div>
        <h1 class="font-bold mt-2">
          {{ collateralTokenDetails.name }} Balance (Collateral)
        </h1>
        <p>
          {{ contractDetails.collateralToken }}
          {{ collateralTokenDetails.symbol }}
        </p>
        <h1 class="font-bold mt-2">
          {{ tokenDetails.name }} Balance (Loan Token)
        </h1>
        <p>{{ contractDetails.token }} {{ tokenDetails.symbol }}</p>
        <h1 class="font-bold mt-2">Ratio</h1>
        <p>{{ contractDetails.ratio }}</p>
        <h1 class="font-bold mt-2">Fee</h1>
        <p>{{ contractDetails.fee }} {{ collateralTokenDetails.symbol }}</p>
        <h1 class="font-bold mt-2">Owner</h1>
        <p>{{ contractDetails.owner }}</p>
      </div>
      <!-- Borrow card -->
      <div class="mt-5 border rounded-lg p-5" v-if="contractDetails.ratio">
        <h1 class="font-bold text-lg">Borrow</h1>
        <form @submit.prevent="borrow">
          <label for="borrowToken"
            >Amount of <b>{{ tokenDetails.name }}</b> to borrow:</label
          ><br />
          <input
            type="number"
            inputmode="decimal"
            :step="'.' + ''.padEnd(17, '0') + '1'"
            v-model="tokenAmount1"
            min="0"
            :max="contractDetails.token"
            name="borrowToken"
            id="borrowToken"
            placeholder="Stablecoin amount"
            class="border rounded-lg px-2 py-2 mt-2 w-full font-mono"
          />

          <h3 class="font-bold mt-3">
            Collateral to pay: {{ collateralAmount }}
            {{ collateralTokenDetails.symbol }}
          </h3>
          <button
            type="button"
            v-if="balances.allowance1 == 0"
            @click="approve1"
            class="rounded-lg border border-blue-500 px-3 py-2 mt-2 text-blue-500 text-sm"
          >
            Approve {{ collateralTokenDetails.symbol }}
          </button>
          <button
            v-else
            type="submit"
            class="rounded-lg bg-blue-500 px-3 py-2 mt-2 text-white text-sm"
          >
            Borrow
          </button>
        </form>
      </div>
      <!-- Repay card -->
      <div class="mt-5 border rounded-lg p-5" v-if="contractDetails.ratio">
        <h1 class="font-bold text-lg">Repay</h1>
        <form @submit.prevent="repay">
          <label for="borrowToken"
            >Amount of <b>{{ tokenDetails.name }}</b> to repay:</label
          ><br />
          <input
            type="number"
            inputmode="decimal"
            :step="'.' + ''.padEnd(17, '0') + '1'"
            v-model="tokenAmount2"
            min="0"
            :max="balances.token"
            name="borrowToken"
            id="borrowToken"
            placeholder="Stablecoin amount"
            class="border rounded-lg px-2 py-2 mt-2 w-full font-mono"
          />

          <h3 class="font-bold mt-3">
            Collateral to be received: {{ collateralAmountRepay }}
          </h3>
          <button
            type="button"
            v-if="balances.allowance0 == 0"
            @click="approve0"
            class="rounded-lg border border-blue-500 px-3 py-2 mt-2 text-blue-500 text-sm"
          >
            Approve {{ tokenDetails.symbol }}
          </button>
          <button
            v-else
            type="submit"
            class="rounded-lg bg-blue-500 px-3 py-2 mt-2 text-white text-sm"
          >
            Repay
          </button>
        </form>
      </div>
    </div>
  </div>
</template>
