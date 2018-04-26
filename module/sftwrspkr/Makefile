ifneq ($(KERNELRELEASE),)

obj-m := sftwrspkr.o
#EXTRA_CFLAGS := $(CFLAGS) -std=gnu99

else

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

endif

