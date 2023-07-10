#!/bin/bash
########################################################################
#
#    Script mkcplpack
#    ----------------
#
#    Purpose : In the framework of a pack : to make the compilation
#    -------
#
#    Usage : mkcplpack
#    -----
#
#    Environment variables :
#    ---------------------
#            GMKROOT        : gmkpack root directory
#            MKMAIN         : directory of local source files
#            MKTOP          : directory of all source files
#            GMKWRKDIR         : main working directory
#            ICS_ERROR      : error file
#            GMKINTFB       : relative auto-generated interfaces blocks directory
#            GMKFYPPF90     : directory of .F90 files generated from .fypp files
#            ICS_ECHO       : Verboose level
#            AWK
#            GMKVIEW        : list of branches, from bottom to top
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

GMK_SUPPORT=${GMK_SUPPORT:=$PREFIX/gmkpack/support}

$GMKROOT/aux/licensepack.sh
if [ $? -ne 0 ] ; then
  exit 1
fi

if [ "$ICS_ICFMODE" = "off" ] ; then
  echo
  echo "         #    #    ##    #####   #    #     #    #    #   ####"
  echo "         #    #   #  #   #    #  ##   #     #    ##   #  #    #"
  echo "         #    #  #    #  #    #  # #  #     #    # #  #  #"
  echo "         # ## #  ######  #####   #  # #     #    #  # #  #  ###"
  echo "         ##  ##  #    #  #   #   #   ##     #    #   ##  #    #"
  echo "         #    #  #    #  #    #  #    #     #    #    #   ####"
  echo
  echo "                   COMPILATION IS SWITCHED OFF."
  echo "         PROCEEDING LIBRARIES AND BINARIES MIGHT NOT BE SAFE !"
  echo
  exit 0
elif [ "$ICS_ICFMODE" != "full" ] && [ "$ICS_ICFMODE" != "incr" ] ; then
  echo
  echo "Wrong value \"$ICS_ICFMODE\" for ICS_ICFMODE : should be \"full\", \"incr\" or \"off\"."
  echo "Reset to \"full\""
  ICS_ICFMODE=full
  echo
fi

PREFLIGHT=1
if [ "$ICS_ICFMODE" = "incr" ] ; then
  if [ "$ICS_START" ] ; then
    if [ "$ICS_START" -gt 0 ] ; then
      PREFLIGHT=0
    fi 
  fi
fi

if [ $PREFLIGHT -eq 1 ] ; then
# Preflight !
  if [ "$GMK_HUB_DIR" ] ; then
    if [ -d $TARGET_PACK/$GMK_HUB_DIR ] ; then
      $GMKROOT/aux/hubpack.sh
      N=$?
      if [ $N -ne 0 ] ; then
        echo "Abort job."
        exit 1
      fi
    fi
  fi
fi

MyTmp=$GMKWRKDIR/mkcplpack
mkdir -p $MyTmp
find $MyTmp -name "*" -type f | xargs /bin/rm -f

# A dirty trick I will get rid of later :
export ICS_ERROR=$GMKWRKDIR/ics_error

export GMAKDIR=$MKTOP/.gmak

# Directory where to store F90 files generated from .fypp files
if [ ! "$GMKFYPPF90" ] ; then
  export GMKFYPPF90=.fypp
  N=$(find $MKTOP/*/$vob -name "*.fypp" -type f | wc -l)
  if [ $N -gt 0 ] ; then
#   preemptive !
    mkdir -p $MKTOP/$GMKLOCAL/$GMKFYPPF90/$vob
  fi
fi

# List of projects:
# ================

#   Condition to generate interface blocks :
#   For a main pack, the source code should contain inclusions of files with extension .intfb.h, unless
#   that files exists already in the explicit source-code.
#   For Surfex, there should be a dummy source-code file containing such a line.
#   For now this file is named "autogen_modintfb.h"
#   Other packs need only that the directory .intfb exists in the main pack for the concerned project :
#   That last condition is sufficient for main pack as well, provided the
#   starting level of compilation is bigger than 0.
NBRANCHES=$(cat $TARGET_PACK/$GMK_VIEW | wc -l)
echo
echo "Determining projects to be handled with autogenerated explicit interfaces ..."
# Auto-generated interface blocks project list (INTFB_PROJLIST are the suplementary user ones) :
# List of well-known projects with autogenerated interfaces :
\ls -1 $GMKROOT/intfb | sort -u > $MyTmp/all_intfb
# List of apparently effective projects with autogenerated interfaces :
\ls -1dp $MKTOP/$GMKLOCAL/* $MKTOP/$GMKMAIN/* $MKTOP/${GMKINTER}*/* 2>/dev/null \
  | grep "/$" | sed "s/\/$//" | $AWK -F "/" '{print $NF}' | grep -v "^\.$" | sort -u > $MyTmp/my_projects.unique
export INTFB_TMP_LIST="$(echo $(comm -12 $MyTmp/my_projects.unique $MyTmp/all_intfb)) $INTFB_PROJLIST"
\rm -f $MyTmp/all_intfb
unset INTFB_ALL_LIST
if [ "$INTFB_TMP_LIST" ] ; then
  if [ $NBRANCHES -eq 1 ] ; then
# List of pseudo-autogenerated explicit interfaces:
    find $MKTOP/$GMKLOCAL/ -depth -type f -name "*.intfb.h" -print 2>/dev/null | \
     $AWK -F "/" '{print $NF}' | sort -u > $MyTmp/explicit_intfbfiles
  fi
  for prj in $(eval echo $INTFB_TMP_LIST) ; do
    if [ $NBRANCHES -eq 1 ] ; then
#   List of included autogenerated explicit interfaces in this project, unless previously done :
      $GMKROOT/aux/findintfb.pl $MKTOP/$GMKLOCAL/$prj | sort -u > $MyTmp/included_intfbfiles
      NINTFB=$(comm -13 $MyTmp/explicit_intfbfiles $MyTmp/included_intfbfiles | wc -l)
    else 
      NINTFB=$(find $MKTOP/$GMKMAIN/$GMKINTFB -type d -name "$prj" -print 2>/dev/null | wc -l)
    fi
    if [ $NINTFB -gt 0 ] ; then
      echo $prj >> $MyTmp/all_intfb 
    fi
  done
  if [ -s $MyTmp/all_intfb ] ; then
    INTFB_ALL_LIST=$(echo $(cat $MyTmp/all_intfb))
    export INTFB_ALL_LIST
    echo "$INTFB_ALL_LIST"
  fi
else
  echo "...None."
fi
echo
\rm -f $MyTmp/all_intfb

# Prepare for ODB now because it will be used in the compilation step
export ODB98NAME=$TARGET_PACK/$GMKSYS/odb98.x

if [ "$ICS_ICFMODE" = "incr" ] ; then
  if [ "$ICS_START" != "" ] ; then
    if [ "$ICS_START" -gt 0 ] ; then
      cd $MyTmp
      fgrep GMKNAME $GMAKDIR/view > viewmods.sds
      tar xf $GMAKDIR/ics_list.tar
      cat ics_list.* > complist
      export INCDIR_LIST=$MyTmp/incdirlist
      $GMKROOT/aux/incdirpack.sh
      if [ -s $INCDIR_LIST ] ; then
        echo "   provisional list of include directories for preprocessing :"
        cat $INCDIR_LIST
      fi
      $GMKROOT/aux/icspack.sh $MyTmp/viewmods.sds $MyTmp/complist
      if [ -f $ICS_ERROR ] ; then
        echo "Abort job."
        cd $GMKWRKDIR
        \rm -rf mkcplpack
        exit 1
      else
        cd $GMKWRKDIR
        \rm -rf mkcplpack
        exit 0
      fi
    fi
  fi
else
  echo
  echo ------ Make compilation lists ---------------------------------------
fi

# Clean environment :
# -----------------

# It is safe to reset the pack, anyway :
if [ ! "$GMK_NO_RESET" ] && [ "$ICS_ICFMODE" = "full" ] ; then
  \rm -f $MKTOP/.incpath.local  $MKTOP/.modpath.local
  \rm -f $GMAKDIR/local.sds.old $GMAKDIR/view $GMAKDIR/local.sds $GMAKDIR/ics_list.tar $GMAKDIR/istart
fi
# for a while, until every gmkpack-user uses this version or the next ones :
#(because the file has been replaced be a hidden one)
\rm -f $MKMAIN/gmak.pl $MKMAIN/comp_list $MKMAIN/gmak.list $MKMAIN/gmak.inc $MKMAIN/gmak.log

# For old packs : if background gmak data descriptors does not exist, fetch them now :
if [ -f $MKTOP/main/gmak.pl ] && [ ! -f $GMAKDIR/main.sds ] ; then
  mkdir -p $GMAKDIR 2>/dev/null
  for view in $(cat $TARGET_PACK/.gmkview) ; do
    if [ "$view" != "$GMKLOCAL" ] ; then
      echo "source descriptors for branch $view missing, making it now."
      link=$(ls -l $MKTOP/$view | $AWK '{print $NF}')
      dirtop=$(dirname $link)
      basetop=$(basename $link)
      if [ -f $dirtop/$basetop/gmak.pl ] ; then
#       gco style, take it like it is (the operation is neutral)
        \ln -s $dirtop/$basetop/gmak.pl $GMAKDIR/${view}.sds
      elif [ -f $dirtop/.gmak/${basetop}.sds ] ; then
        cat $dirtop/.gmak/${basetop}.sds 2>/dev/null | sed "s/{branch} = '${basetop}'; /{branch} = '${view}'; /" > $GMAKDIR/${view}.sds
      else
        echo "Error. No file $dirtop/.gmak/${basetop}.sds"
        cd $GMKWRKDIR
        \rm -rf mkcplpack
        exit 1
      fi
    fi
  done
fi

# For gmak:
# add autogenerated interfaces (headers or modules) in the dependency research:
# add F90 files processed by fypp :
export MKPROJECT="$MKPROJECT $GMKINTFB $GMKFYPPF90"
export MKTMP=$MyTmp
if [ "$(\ls -1t $TARGET_PACK/.gmkfile 2>/dev/null | tail -1)" ] ; then
  export GMKFILEPATH=$TARGET_PACK/.gmkfile
  export FLAVOUR=$(\ls -1t $GMKFILEPATH | tail -1)
elif [ -f $HOME/.gmkpack/arch/$GMKFILE.$GMK_OPT ] ; then
  export GMKFILEPATH=$HOME/.gmkpack/arch
  export FLAVOUR=$GMKFILE.$GMK_OPT
elif [ -f $GMK_SUPPORT/arch/$GMKFILE.$GMK_OPT ] ; then
  export GMKFILEPATH=$GMK_SUPPORT/arch
  export FLAVOUR=$GMKFILE.$GMK_OPT
else
  echo "Error : no file ${GMKFILE}* could be found either in source pack, \$HOME/.gmkpack/arch or \$GMK_SUPPORT/arch."
  cd $GMKWRKDIR
  \rm -rf mkcplpack
  exit 1
fi

echo "pack content ..."

cd $MKMAIN
if [ ! -s $GMKWRKDIR/.ignored_files ] ; then
  $GMKROOT/util/scanpack > $MyTmp/packlist
else
  $GMKROOT/util/scanpack | sort -u > $MyTmp/packlist.tmp
  sort -u $GMKWRKDIR/.ignored_files >  $MyTmp/ignored_files
  comm -23 $MyTmp/packlist.tmp $MyTmp/ignored_files > $MyTmp/packlist
fi
cd $MyTmp
# VPP stuff :
$GMKROOT/aux/vppstuffpack.sh $MyTmp/packlist
echo
# projects-specific stuff :
for project in $(cat $MyTmp/packlist | cut -d"/" -f1 | sort -u) ; do
  if [ -f $GMKROOT/aux/${project}stuffpack.sh ] ; then
    $GMKROOT/aux/${project}stuffpack.sh $MyTmp/packlist
    if [ $? -ne 0 ] ; then
      echo "Abort job."
      cd $GMKWRKDIR
      \rm -rf mkcplpack
      exit 1
    fi
    echo
  fi
done

# Pre-processing : fypp files
if [ -s packlist ] ; then
  if [ ! "$GMK_FYPP" ] ; then
    export GMK_FYPP=fypp
  fi
  if [ $(grep -c "\.[hf]ypp$" packlist) -ne 0 ] || [ $(grep -c "\.yaml$" packlist) -ne 0 ] ; then
    echo "process fypp/hypp/yaml files ..."
#   yaml + [hf]ypp files in local pack :     
    egrep "(\.[hf]ypp$|\.yaml$)" packlist > packlist_yaml_ypp
    # all but fypp files in local pack (they will cause generation of .F90 files) :     
    grep -v "\.fypp$" packlist > packlist_others
    $GMKROOT/aux/fypppack.sh packlist_yaml_ypp packlist_F90 residual_modules_directories
    if [ $? -ne 0 ] ; then
      cd $GMKWRKDIR
      \rm -rf mkcplpack
      exit 1
    else
#     Generation of of all .F90 is successfull => we can replace the .fypp files in packlist 
#     by the corresponding .F90 files :
      cat packlist_others packlist_F90 > packlist
    fi
  fi
fi

if [ "x$GMK_DR_HOOK_ALL" != "x" ] ; then
  $GMKROOT/aux/drhook_all.pl --create-library $GMK_DR_HOOK_ALL_FLAGS \
    --fc="$FRTNAME $FRTFLAGS $FREE_FRTFLAG $F90_CPPFLAG $MACROS_FRT" --ar="$AR -qv"
fi

if [ -s packlist ] ; then

# Save previous version of source descriptors for local branch :
  CURRENT=$GMAKDIR/$GMKLOCAL.sds
  OLD=${CURRENT}.old
  if [ -f $CURRENT ] ; then
    \cp $CURRENT $OLD
  fi

  if [ "$DEP" = "yes" ] && [ -f $GMAKDIR/.depsearch ] ; then
    check_update=yes
  elif [ "$DEP" !=  "yes" ] && [ ! -f $GMAKDIR/.depsearch ] ; then
    check_update=yes
  else
    unset check_update
  fi
  if [ "$check_update" ] ; then
    cmp -s $GMAKDIR/${GMKLOCAL}.sds $GMAKDIR/${GMKLOCAL}.sds.old 2>/dev/null
    code=$?
  else
    \rm -f $GMAKDIR/ics_list.tar -f $GMAKDIR/view
    code=1
  fi
  if [ $code -eq 0 ] ; then
#   If the descriptors have not changed, then the Include/source pathes must be up-to-date:
    echo "Assume include/source paths are up-to-date ..."
  else
    touch $MyTmp/modules_list
    echo "Provisional include/source paths ..."
    $GMKROOT/aux/pathpack.sh $MyTmp/packlist $MyTmp/modules_list
  fi

  export INCDIR_LIST=$MyTmp/incdirlist
  $GMKROOT/aux/incdirpack.sh
  if [ -s $INCDIR_LIST ] ; then
    echo "   provisional list of include directories for preprocessing :"
    cat $INCDIR_LIST
  fi

# Create descriptors file local.sds
  echo "gmak local sources descriptors ..."

# One should work on preprocessed files for C and C++ code in order to avoid certain include files
# to be considered while an indefined cpp macro would have excluded them ;
# Besides, an error has to be fatal otherwise the related C/C++ files would be removed 
# from the list of files
# include directories :
  $GMKROOT/aux/Pcpppack.sh packlist local.sds cpp_errors
  if [ -s cpp_errors ] ; then
    echo "preprocessing failed on the following files :"
    cat cpp_errors
    cd $GMKWRKDIR
    \rm -rf mkcplpack
    exit 1
  fi

  fgrep GMKNAME local.sds | $AWK -F"'" '{print $2}' > modules_list

# Add auto-generated interface blocks:
  touch $MyTmp/intfblist
  if [ "$INTFB_ALL_LIST" ] ; then
    for prj in $(eval echo $INTFB_ALL_LIST) ; do
      echo "Auto-generated explicit interface blocks on projects $prj ..."
#     1/ filter out .fypp directory from subroutines/modules of project $prj
      grep -v "^${GMKFYPPF90}\/$prj" $MyTmp/packlist > $MyTmp/F90_list
      grep -v "^${GMKFYPPF90}\/$prj" $MyTmp/modules_list > $MyTmp/F90_modules
      if [ -s $MyTmp/F90_list ] ; then
#       Define corresponding location of .F90 files :
        export GMKBUILD=$MKMAIN
        $GMKROOT/aux/Pmkintfb.sh $MyTmp/F90_list $MyTmp/F90_modules $MyTmp/${prj}_intfblist ${prj} $GMKWRKDIR/intfbdir $GMKWRKDIR/cppdir
        if [ $? -ne 0 ] ; then
          cd $GMKWRKDIR
          \rm -rf mkcplpack
          exit 1
        elif [ -s ${prj}_intfblist ] ; then
          cat ${prj}_intfblist >> intfblist
        fi
      fi
#     2/ select .fypp directory from subroutines/modules of project $prj
      grep "^${GMKFYPPF90}\/$prj" $MyTmp/packlist | sed "s:^${GMKFYPPF90}/::g" > $MyTmp/fypp_list
      grep "^${GMKFYPPF90}\/$prj" $MyTmp/modules_list | sed "s:^${GMKFYPPF90}/::g" > $MyTmp/fypp_modules
      if [ -s $MyTmp/fypp_list ] ; then
#       Define corresponding location of .F90 files :
        export GMKBUILD=${MKMAIN}/${GMKFYPPF90}
        $GMKROOT/aux/Pmkintfb.sh $MyTmp/fypp_list $MyTmp/fypp_modules $MyTmp/${prj}_fyppintfblist ${prj} $GMKWRKDIR/intfbdir $GMKWRKDIR/cppdir
        if [ $? -ne 0 ] ; then
          cd $GMKWRKDIR
          \rm -rf mkcplpack
          exit 1
        elif [ -s ${prj}_fyppintfblist ] ; then
          cat ${prj}_fyppintfblist >> intfblist
        fi
      fi 
    done
    if [ -s intfblist ] ; then
      echo "gmak auto-generated interface blocks descriptors ..."
      \mv packlist packlist.bak
      \mv local.sds local.sds.bak
      /bin/cp intfblist packlist
      export MKBRANCHES="$GMKVIEW"
      $GMKROOT/aux/gmak.pl -d > /dev/null
      cat local.sds >> local.sds.bak
      \mv local.sds.bak local.sds
      cat packlist >> packlist.bak
      \mv packlist.bak packlist
    fi
  fi

  sort -u local.sds > $GMAKDIR/$GMKLOCAL.sds

# As well as the compilation list and the "view" descriptors :
  if [ $code -eq 0 ] &&  [ -f $GMAKDIR/ics_list.tar ] && [ -f $GMAKDIR/view ] ; then
    echo "Assume ordered compilation lists and view are up-to-date ..."
    fgrep GMKNAME $GMAKDIR/view > $MyTmp/viewmods.sds
    tar xf $GMAKDIR/ics_list.tar
    cat ics_list.* > complist
  else
    $GMKROOT/aux/sortpack.sh $MyTmp/viewmods.sds $MyTmp/complist
    if [ $? -ne 0 ] ; then
      cd $GMKWRKDIR
      \rm -rf mkcplpack
      exit 1
    fi
  fi

  if [ $code -ne 0 ] ; then
#   Update with modules and autogenerated interfaces :
    echo "Additional include/source paths ..."
    $GMKROOT/aux/intfb_pathpack.sh $MyTmp/intfblist $MyTmp/modules_list
  fi

  if [ -s residual_modules_directories ] ; then
    echo "residual modules directories from fypp preprocessing :"
    cat residual_modules_directories | sort -u | tee -a $MKTOP/.modpath.local
  fi

  $GMKROOT/aux/incdirpack.sh
  if [ -s $INCDIR_LIST ] ; then
    echo "   final list of include directories for compilation :"
    i=0
    for dir in $(cat $INCDIR_LIST) ; do
      i=$((i+1))
      echo "[$i] $dir"
#     Sometimes the include directory is listed by anticipation.
#     To avoid a possible warning, create the missing directories :
      if [ ! -d $dir ] ; then
        mkdir -p $dir
      fi
    done
  fi

# Compile everything :
  $GMKROOT/aux/icspack.sh $MyTmp/viewmods.sds $MyTmp/complist
  if [ -f $ICS_ERROR ] ; then
    echo "Abort job."
    cd $GMKWRKDIR
    \rm -rf mkcplpack
    exit 1
  fi

else

  echo
  echo "Pack is up-to-date or empty."

  if [ "$GMKINTFB" ] ; then
    \rm -rf $GMKINTFB
  fi

fi
cd $GMKWRKDIR
\rm -rf mkcplpack
exit 0
