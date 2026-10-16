/* SPDX-License-Identifier: GPL-2.0-only */
/* macOS port: tracepoints are compiled out. */
#ifndef __MT7601U_TRACE_H
#define __MT7601U_TRACE_H
#include "mt7601u.h"
#include "mac.h"
#define trace_bbp_read(...) do {} while (0)
#define trace_bbp_write(...) do {} while (0)
#define trace_freq_cal_adjust(...) do {} while (0)
#define trace_freq_cal_offset(...) do {} while (0)
#define trace_mt_mcu_msg_send(...) do {} while (0)
#define trace_mt_rx(...) do {} while (0)
#define trace_mt_rx_dma_aggr(...) do {} while (0)
#define trace_mt_submit_urb(...) do {} while (0)
#define trace_mt_submit_urb_sync(...) do {} while (0)
#define trace_mt_tx(...) do {} while (0)
#define trace_mt_tx_dma_done(...) do {} while (0)
#define trace_mt_tx_status_cleaned(...) do {} while (0)
#define trace_mt_vend_req(...) do {} while (0)
#define trace_read_temp(...) do {} while (0)
#define trace_reg_read(...) do {} while (0)
#define trace_reg_write(...) do {} while (0)
#define trace_rf_read(...) do {} while (0)
#define trace_rf_write(...) do {} while (0)
#define trace_set_key(...) do {} while (0)
#define trace_set_shared_key(...) do {} while (0)
#define trace_temp_mode(...) do {} while (0)
#endif
