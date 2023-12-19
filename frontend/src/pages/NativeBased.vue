<script lang="ts" setup>
import Navbar from '../components/Navbar.vue'
import { Jazzicon } from 'vue-connect-wallet'
import { useStore } from '../store/useStore'
import { storeToRefs } from 'pinia';
import { ethers } from 'ethers'
import { formatEther, parseEther } from 'ethers/lib/utils';
import { onMounted, reactive, watch, computed, ref } from 'vue';
import Token from '../abis/Token.json'
import LoanShark from '../abis/LoanShark.json'

const { address } = storeToRefs(useStore())

const provider = new ethers.providers.Web3Provider(window.ethereum)

const balances = reactive({
    eth: 0,
    token: 0,
    allowance: 0
})

const contractDetails = reactive({
    address: null as string | null,
    eth: 0,
    token: 0,
    ratio: null as number | null,
    fee: null as number | null
})

const tokenDetails = reactive({
    name: null as string | null,
    symbol: null as string | null,
    address: null as string | null,
})

const tokenAmount1 = ref(null as number | null)
const tokenAmount2 = ref(null as number | null)

const ethAmount = computed(() => {
    if (!contractDetails.ratio || !tokenAmount1.value) return 0
    return (tokenAmount1.value / contractDetails.ratio).toFixed(18)
})

const ethAmountRepay = computed(() => {
    if (!contractDetails.ratio || !tokenAmount2.value) return 0
    return ((tokenAmount2.value / contractDetails.ratio) - (contractDetails.fee ?? 0)).toFixed(18)
})

let token: any = null
let loanshark: any = null

onMounted(init)
watch(address, init)

async function init() {
    if (!address.value) return

    // Get loan shark contract
    loanshark = new ethers.Contract(LoanShark.address, LoanShark.abi, provider.getSigner())
    contractDetails.address = LoanShark.address

    const tokenAddress = await loanshark.stablecoin()
    // Get token contract
    token = new ethers.Contract(tokenAddress, Token.abi, provider.getSigner())
    tokenDetails.address = tokenAddress
    tokenDetails.name = await token.name()
    tokenDetails.symbol = await token.symbol()

    getBalances()
    getLoanSharkDetails()
    getAllowance()
}

async function getBalances() {
    if (!address.value) return

    // Get User's ETH and Token balance
    balances.eth = +formatEther(await provider.getBalance(address.value))
    balances.token = +formatEther(await token.balanceOf(address.value))

    // Get Contract's ETH and Token balance 
    contractDetails.eth = +formatEther(await provider.getBalance(LoanShark.address))
    contractDetails.token = +formatEther(await token.balanceOf(LoanShark.address))
}

async function getLoanSharkDetails() {
    if (!loanshark) return
    contractDetails.ratio = +formatEther(await loanshark.ratio())
    contractDetails.fee = +formatEther(await loanshark.fee())
}

async function getAllowance() {
    balances.allowance = +formatEther(await token.allowance(address.value, contractDetails.address))
}

async function approve() {
    if (!contractDetails.address) return
    const result = await token.approve(contractDetails.address, ethers.constants.MaxUint256)
    await result.wait(1)
    getAllowance()
}

async function borrow() {
    if (!tokenAmount1.value) return
    const result = await loanshark.borrow({
        value: parseEther(ethAmount.value.toString())
    })
    await result.wait(1)
    init()
}

async function repay() {
    if (!tokenAmount2.value) return
    const result = await loanshark.repay(parseEther(tokenAmount2.value.toString()))
    await result.wait(1)
    init()
}

</script>

<template>
    <div class="pb-15">
        <Navbar />
        <div v-if="!address" class="mx-auto mt-10 w-11/12 md:w-1/2">
            <h1>Please connect your wallet to use this Dapp</h1>
        </div>
        <div v-else class="mx-auto w-11/12 md:w-1/2">
            <div class="mt-10 border rounded-lg p-5">
                <h1 class="flex space-x-2 items-center text-sm font-medium">
                    <Jazzicon :diameter="40" :address="address" class="mt-1" /><span>{{ address }}</span>
                </h1>
                <h1 class="font-bold mt-2">ETH Balance</h1>
                <p>{{ balances.eth }}</p>
                <h1 class="font-bold mt-2">{{ tokenDetails.name }} Balance</h1>
                <p>{{ balances.token }}</p>
            </div>
            <div class="mt-5 border rounded-lg p-5">
                <div class="flex space-x-2 items-center">
                    <Jazzicon :diameter="40" :address="contractDetails.address" class="mt-1.5" />
                    <div>
                        <h1 class="text-sm font-bold">LoanShark Contract</h1>
                        <h2 class="text-xs text-gray-500">{{ contractDetails.address }}</h2>
                    </div>
                </div>
                <h1 class="font-bold mt-2">ETH Balance</h1>
                <p>{{ contractDetails.eth }}</p>
                <h1 class="font-bold mt-2">{{ tokenDetails.name }} Balance</h1>
                <p>{{ contractDetails.token }}</p>
                <h1 class="font-bold mt-2">Ratio</h1>
                <p>{{ contractDetails.ratio }}</p>
                <h1 class="font-bold mt-2">Fee</h1>
                <p>{{ contractDetails.fee }} ETH</p>
            </div>
            <!-- Borrow card -->
            <div class="mt-5 border rounded-lg p-5" v-if="contractDetails.ratio">
                <h1 class="font-bold text-lg">Borrow</h1>
                <form @submit.prevent="borrow">
                    <label for="borrowToken">Amount of Stablecoins to borrow:</label><br />
                    <input type="number" inputmode="decimal" :step="'.' + ''.padEnd(17, '0') + '1'"
                        v-model="tokenAmount1" min="0" :max="contractDetails.token" name="borrowToken" id="borrowToken"
                        placeholder="Stablecoin amount" class="border rounded-lg px-2 py-2 mt-2 w-full font-mono" />

                    <h3 class="font-bold mt-3">ETH to pay: {{ ethAmount }}</h3>
                    <button type="submit"
                        class="rounded-lg bg-blue-500 px-3 py-2 mt-2 text-white text-sm">Borrow</button>
                </form>
            </div>
            <!-- Repay card -->
            <div class="mt-5 border rounded-lg p-5" v-if="contractDetails.ratio">
                <h1 class="font-bold text-lg">Repay</h1>
                <form @submit.prevent="repay">
                    <label for="borrowToken">Amount of Stablecoins to repay:</label><br />
                    <input type="number" inputmode="decimal" :step="'.' + ''.padEnd(17, '0') + '1'"
                        v-model="tokenAmount2" min="0" :max="balances.token" name="borrowToken" id="borrowToken"
                        placeholder="Stablecoin amount" class="border rounded-lg px-2 py-2 mt-2 w-full font-mono" />

                    <h3 class="font-bold mt-3">ETH to be received: {{ ethAmountRepay }}</h3>
                    <button type="button" v-if="balances.allowance == 0" @click="approve"
                        class="rounded-lg border border-blue-500 px-3 py-2 mt-2 text-blue-500 text-sm">Approve
                        {{
                                tokenDetails.symbol
                        }}</button>
                    <button v-else type="submit"
                        class="rounded-lg bg-blue-500 px-3 py-2 mt-2 text-white text-sm">Repay</button>
                </form>
            </div>
        </div>
    </div>
</template>