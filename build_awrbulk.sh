#!/bin/ksh
#
#

# 0 Setup
THISBUNDLE=awrbulk_sa
MANIFEST=${THISBUNDLE}.mf

# 1 Checkout.
#


# 2 Bundle.

if [ -d ${DEPLOYROOT}/${THISBUNDLE} ];then
    rm -rf ${DEPLOYROOT}/${THISBUNDLE}
fi

mkdir -p ${DEPLOYROOT}/${THISBUNDLE}
cat ${MANIFEST} | grep -v "^#" | while read line
do

done


# 3 Deploy.
