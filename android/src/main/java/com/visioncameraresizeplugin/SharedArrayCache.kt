package com.visioncameraresizeplugin

import java.util.ArrayDeque
import java.util.IdentityHashMap

internal class SharedArrayCache<K : Any, V : Any>(
  private val maxSize: Int,
  private val create: (K) -> V
) {
  private val values = IdentityHashMap<K, V>()
  private val order = ArrayDeque<K>()

  init {
    require(maxSize > 0) { "maxSize must be positive" }
  }

  fun getOrCreate(key: K): V {
    values[key]?.let { return it }

    while (order.size >= maxSize) {
      values.remove(order.removeFirst())
    }

    return create(key).also { value ->
      values[key] = value
      order.addLast(key)
    }
  }
}
