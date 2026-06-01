#
# Copyright (C) 2013 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# PulsarOS products for Orange Pi Zero 3 (Allwinner H618)
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/pulsaros_zero3.mk

COMMON_LUNCH_CHOICES := \
    pulsaros_zero3-eng \
    pulsaros_zero3-userdebug \
    pulsaros_zero3-user
