package NVHPC;

use strict;
use FindBin qw ($Bin);
use base qw (Exporter);

our @EXPORT = qw ($NVHPC_ROOT $OMPI_PREFIX $CUDA_PREFIX &fixEnv &prefix &site &fixLink);

my ($version, $cuda, $hpcx) = ('23.11', '12.3', '2.16');
our $NVHPC_ROOT = &prefix () . '/nvidia/hpc_sdk/Linux_x86_64/' . $version;
#our $NVHPC_ROOT = '/leonardo/prod/spack/03/install/0.19/linux-rhel8-icelake/nvhpc-23.1/openmpi-4.1.4-6ek2oqarjw755glr5papxirjmamqwvgd';

our $OMPI_PREFIX = "comm_libs/$cuda/hpcx/hpcx-$hpcx/ompi";
#our $OMPI_PREFIX = "openmpi-4.1.4-6ek2oqarjw755glr5papxirjmamqwvgd";
#our $OMPI_PREFIX = "";

our $CUDA_PREFIX= "cuda/$cuda";

sub fixEnv
{
  my @u = qw (CC CXX F77 F90 FC I_MPI_CC I_MPI_CXX I_MPI_F90 I_MPI_FC OMPI_CC OMPI_CXX OMPI_FC);
  delete $ENV{$_} for (@u);

  $ENV{LD_LIBRARY_PATH} = "$NVHPC_ROOT/comm_libs/nvshmem/lib:$NVHPC_ROOT/comm_libs/nccl/lib:$NVHPC_ROOT/$OMPI_PREFIX/lib:$NVHPC_ROOT/math_libs/lib64:$NVHPC_ROOT/compilers/lib:$NVHPC_ROOT/cuda/lib64";
  $ENV{PATH} = "$NVHPC_ROOT/compilers/bin:$ENV{PATH}";
  $ENV{NVHPC_CUDA_HOME} = "$NVHPC_ROOT/$CUDA_PREFIX";

  if (&site () eq 'meteo')
    {
      # Hack for bug in math lib of NVHPC 23.11, provided by Louis Stuber (NVIDIA)
      $ENV{CPATH} = "$Bin/pgi-math-wrapper/";
    }

}

sub prefix
{
  use Sys::Hostname;
  my $host  = &hostname ();
  return '/ec/res4/hpcperm/sor/install' if ($host =~ m/^ac\d+-\d+\.bullx$/o);
  return '/opt/softs' if ($host =~ m/^(?:belenos|taranis)/o);
  return '/leonardo/pub/userexternal/dhaumont/install' if ($host =~m/(?:leonardo)/o);
  die ("Unexpected host : $host");
}

sub site
{
  use Sys::Hostname;
  my $host  = &hostname ();

  for ($host)
    {
      return 'meteo' if (m/^(?:belenos|taranis)/o);
      return 'ecmwf' if (m/^ac\d+-\d+\.bullx$/o);
      return 'leonardo' if (m/(?:leonardo)/o);
    }

  die;
}

sub fixLink
{

  for (@_)
    {
      s/^-l\[(\d+)\]/-l_${1}_/go;
    }

  for my $f (<*.a>)
    {
      if ((my $g = $f) =~ s/^lib\[(\d+)\]\.a$/lib_${1}_.a/o)
        {
          link ($f, $g);
        }
    }

}

1;
