/*

  Pseudo PC-Speaker driver for Linux

  Copyright (c) 2017 Thomas Kremer

*/

/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License version 2 or 3 as
 * published by the Free Software Foundation
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/input.h>
#include <linux/jiffies.h>

MODULE_AUTHOR("Thomas Kremer");
MODULE_DESCRIPTION("Pseudo PC-Speaker driver");
MODULE_LICENSE("LGPL");
//MODULE_ALIAS("sftwrspkr");

// single-device module
static struct input_dev *dev;


static void sftwrspkr_on_sync_timer(unsigned long ignored) {
  input_sync(dev);
}

static DEFINE_TIMER(sftwrspkr_sync_timer, sftwrspkr_on_sync_timer, 0, 0);

#define default_delay msecs_to_jiffies(1)

static void sftwrspkr_delayed_sync(void) {
  del_timer_sync(&sftwrspkr_sync_timer);
  mod_timer(&sftwrspkr_sync_timer,get_jiffies_64()+default_delay);
}

static int sftwrspkr_event(struct input_dev *dev, unsigned int type, unsigned int code, int value) {
  if (type == EV_SYN) {
    if (code == SND_TONE || code == SND_BELL)
      return 0;
    return -1;
  } else if (type == EV_SND) {
    //input_event(dev,EV_SYN,SYN_REPORT,0);
    // freezes the kernel:
      //input_sync(dev);
    sftwrspkr_delayed_sync();
    return 0;
  } else {
    return -1;
  }
}

static int sftwrspkr_add_device(void) {
  int err;
  //struct input_dev *dev;
  dev = input_allocate_device();
  if (!dev) return -ENOMEM;

  dev->name = "Pseudo PC-Speaker";
  // used values of "ACPI Virtual Keyboard Device", since it's as virtual as
  // our device:
  dev->phys = "sftwrspkr/input0";
  dev->id.bustype = BUS_VIRTUAL;
  dev->id.vendor = 0;
  dev->id.product = 0;
  dev->id.version = 4;
  dev->dev.parent = NULL;

  dev->evbit[0] = BIT_MASK(EV_SND);
  dev->sndbit[0] = BIT_MASK(SND_BELL) | BIT_MASK(SND_TONE);
  dev->event = sftwrspkr_event;
  err = input_register_device(dev);
  if (err) {
    input_free_device(dev);
    dev = NULL;
    return err;
  }
  return 0;
}

static void sftwrspkr_remove_device(void) {
  if (dev) {
    input_unregister_device(dev);
  }
}

static int __init sftwrspkr_init(void) {
  return sftwrspkr_add_device();
}

static void __exit sftwrspkr_exit(void) {
  sftwrspkr_remove_device();
}

module_init(sftwrspkr_init);
module_exit(sftwrspkr_exit);

