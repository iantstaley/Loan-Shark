import { createRouter, createWebHistory } from 'vue-router'

const routes = [
    {
        path: '/',
        component: () => import('../pages/Home.vue')
    },
    {
        path: '/native',
        component: () => import('../pages/NativeBased.vue')
    },
    {
        path: '/:pathMatch(.*)*',
        component: () => import('../pages/PathNotFound.vue'),
    }
]


const router = createRouter({
    history: createWebHistory(),
    routes
})

export default router
