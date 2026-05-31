package com.visioncameraresizeplugin

import java.nio.ByteBuffer
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotSame
import kotlin.test.assertSame

class SharedArrayCacheTest {
  @Test
  fun reusesWrapperForSameNativeBufferIdentity() {
    val cache = SharedArrayCache<ByteBuffer, Any>(2) { Any() }
    val buffer = ByteBuffer.allocateDirect(8)

    assertSame(cache.getOrCreate(buffer), cache.getOrCreate(buffer))
  }

  @Test
  fun treatsEqualBuffersWithDifferentIdentityAsSeparateNativeBuffers() {
    val cache = SharedArrayCache<ByteBuffer, Any>(2) { Any() }
    val first = ByteBuffer.allocateDirect(8)
    val second = ByteBuffer.allocateDirect(8)

    assertNotSame(cache.getOrCreate(first), cache.getOrCreate(second))
  }

  @Test
  fun evictsOldestWrapperWhenCacheIsFull() {
    var created = 0
    val cache = SharedArrayCache<ByteBuffer, Int>(2) { ++created }
    val first = ByteBuffer.allocateDirect(8)
    val second = ByteBuffer.allocateDirect(8)
    val third = ByteBuffer.allocateDirect(8)

    assertEquals(1, cache.getOrCreate(first))
    assertEquals(2, cache.getOrCreate(second))
    assertEquals(3, cache.getOrCreate(third))
    assertEquals(4, cache.getOrCreate(first))
  }

  @Test
  fun rejectsNonPositiveMaxSize() {
    assertFailsWith<IllegalArgumentException> {
      SharedArrayCache<ByteBuffer, Any>(0) { Any() }
    }
  }
}
