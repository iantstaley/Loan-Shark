import { defineStore } from 'pinia'

export const useStore = defineStore('Store', {
    state: () => ({
        address: null as string | null
    })
})
