package com.example.autovrt

sealed class Screen(val route: String) {
    object First : Screen("first")
    object Second : Screen("second")
}

