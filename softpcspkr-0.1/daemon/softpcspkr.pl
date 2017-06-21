#!/usr/bin/perl

# Copyright (c) 2017 by Thomas Kremer
# License: GNU GPL ver. 2 or 3

use strict;
use warnings;

use Math::Trig "pi";

$| = 1;

sub slurp {
  my $fname = shift;
  open(my $f, "<", $fname) or return "";
  local $/ = undef;
  my $content = <$f>//"";
  close($f);
  return $content;
}

sub load_wav_s16le {
  my $fname = shift;
  my $wav = slurp($fname);
  #return if length($wav) < 44;
  $wav =~ s/^RIFF....WAVEfmt \x10\0\0\0(................)data....//
     or return undef;
  my ($type,$channels,$samplerate,$bytes_per_channelsamplerate,
      $bytes_per_channelsample,$bits_per_sample) = unpack "vv V V vv",$1;
  return if $type != 1; # PCM
  return if $channels < 1;
  return if $samplerate != 44100; # TODO: support.
  return if $bits_per_sample != 16; # TODO: support.
  return if $bits_per_sample*$channels != $bytes_per_channelsample*8;
  return if $bits_per_sample*$channels*$samplerate != $bytes_per_channelsamplerate*8;

  if ($channels > 1) {
    #  just extract first channel.
    $wav = pack "s*", unpack "(s x[s[".($channels-1)."]])*", $wav;
  }
  return $wav;
}

sub load_wavs {
  my $dir = shift;
  my @res;
  for (glob($dir."/*.wav")) {
    my $pcm = load_wav_s16le($_);
    push @res, $pcm if defined $pcm;
  }
  return \@res;
}

sub open_evdev {
  my @inputs = glob("/sys/class/input/event*");
  my $dev = undef;
  for (@inputs) {
    if (slurp("$_/device/phys") =~ m{^sftwrspkr/input0$}) {
      s{^/sys/class/input/}{};
      $dev = "/dev/input/$_";
      die "device exists, but has no device node in /dev/input!" unless -e $dev;
      die "device node is not a char device!" unless -c $dev;
      die "we have no read permission to the device node!" unless -r $dev;
      open(my $f,"<",$dev) or die "cannot open $dev: $!!";
      return $f;
    }
  }
  die "could not find sftwrspkr event device";
}

my $sizeof_input_event = length(pack("l! l! S S l"));

sub get_event {
  my $dev = shift;
  my $buf;
  # structure is defined in /usr/include/linux/input.h:
  # struct input_event { struct timeval { time_t tv_sec, suseconds_t tv_usec} __u16 type; __u16 code; __s32 value;}
  # time_t==suseconds_t==__SLONGWORD_TYPE==long int == __s64
  # pack string: "l! l! S S l"
  my $res = sysread($dev,$buf,$sizeof_input_event);
  return $buf;
}

sub is_tone_on_event {
  my $event = shift;
  my ($type,$code,$value) = unpack("x[l! l!] S S l",$event);
  return $type == 18 # sound
      && $code == 2  # tone
      && $value != 0;
}

my ($aplay_handle,$aplay_buffer);
if (@ARGV) {
  my $dir = shift;
  $aplay_buffer = load_wavs($dir);
}
sub play_tone {
  if (!defined $aplay_handle) {
    open($aplay_handle,"|-",qw(aplay -q -f S16_LE -c 1 -t raw -r 44100)) or die "cannot exec aplay";
  }
  if (!defined $aplay_buffer) {
    my $f = 660;
    my $samps_per_period = 44100/$f;
    my $len = 44100/5;
    my $volume = 32767*0.1;
    $aplay_buffer = pack "s*", map $volume*sin($_/$samps_per_period*2*pi)*($_/$len*(1-$_/$len)), 0..$len;
  }
  my $buf = $aplay_buffer;
  if (ref $buf eq "ARRAY") {
    $buf = $$buf[rand(scalar @$buf)];
  }
  print $aplay_handle $buf;
  close($aplay_handle);
  $aplay_handle = undef;
}


my $evdev = open_evdev();

while (my $ev = get_event($evdev)) {
  if (is_tone_on_event($ev)) {
    #print "play.";
    play_tone($ev);
  }
}


