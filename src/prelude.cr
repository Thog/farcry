require "primitives"
require "atomic"
require "struct"
require "./internal/external_types"
require "./internal/utils"
require "value"
require "nil"
require "comparable"
require "enum"
require "proc"

{% if flag?(:bits64) %}
  lib LibC
    alias SizeT = UInt64
    alias SSizeT = Int64
    alias ULong = UInt64
  end
{% else %}
  lib LibC
    alias SizeT = UInt32
    alias SSizeT = Int32

    alias ULong = UInt64
  end
{% end %}

lib LibC
  fun malloc(size : SizeT) : Void*
  fun free(ptr : Void*)
  fun realloc(ptr : Void*, size : SizeT) : Void*
end

require "macros"
require "gc"
require "./i386_utils"
require "./logger/impl"

lib LinkerScript
  $bss_start = BSS_START : UInt8
  $bss_end = BSS_END : UInt8
  $kernel_start = KERNEL_START : UInt8
  $kernel_end = KERNEL_END : UInt8
end

fun __crystal_once_init : Void*
  Pointer(Void).new 0
end

fun __crystal_raise_overflow : NoReturn
  raise "overflow exception"
end

def raise(message : String) : NoReturn
  Logger.error "Crystal exception raised:"
  Logger.error message
  abort
end

fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
  unless flag.value
    Proc(Nil).new(initializer, Pointer(Void).new 0).call
    flag.value = true
  end
end

# GRUB entrypoint
fun __farcry_entrypoint
  # test = Atomic(UInt32).new 5
  asm("
        # Because it's anoying without this
        .intel_syntax noprefix

        # As Multiboot 2 spec this, we should setup some stack.
        lea esp, __farcry_early_stack_top
        mov ebp, esp

        # We then convert the args passed by Multiboot 2 into somthing that follow the C convention for x86
        push ebx
        push eax

        call __farcry_real_entrypoint

        # if we return here, we halt the CPU.
        hlt
    ")
end

module Multiboot2
  @@info_address : UInt64 = 0

  def self.init_from_arguments(multiboot2_magic, multboot2_address)
    @@info_address = multboot2_address.address
  end
end

lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

# Farcry real entrypoint
fun __farcry_real_entrypoint(multiboot2_magic : UInt32, multboot2_address : Void*) : NoReturn
  bss_size = (pointerof(LinkerScript.bss_end).address - pointerof(LinkerScript.bss_start).address).to_u32
  memset(pointerof(LinkerScript.bss_start), 0, bss_size)

  Multiboot2.init_from_arguments(multiboot2_magic, multboot2_address)
  LibCrystalMain.__crystal_main(0, Pointer(Pointer(UInt8)).new 0)

  # Never return
  while true
    asm("hlt")
  end
end
