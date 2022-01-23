#! /bin/bash

WORKING_DIR=/mnt/sfs_turbo/gyx/PPT

if [[ $DLS_TASK_NUMBER == 1 ]]; then
    MASTER_ADDR=localhost
    MASTER_PORT=6000
    NNODES=1
    NODE_RANK=0
else
    MASTER_HOST="$BATCH_CUSTOM0_HOSTS"
    MASTER_ADDR="${MASTER_HOST%%:*}"
    MASTER_PORT="${MASTER_HOST##*:}"
    NNODES="$DLS_TASK_NUMBER"
    NODE_RANK="$DLS_TASK_INDEX"
fi

GPUS_PER_NODE=8
DISTRIBUTED_ARGS="--nproc_per_node $GPUS_PER_NODE \
                  --nnodes $NNODES --node_rank $NODE_RANK \
                  --master_addr $MASTER_ADDR \
                  --master_port $MASTER_PORT"

OPTIONS_NCCL="NCCL_DEBUG=info"

MP_SIZE=1

DATA_EXT=".jsonl"
DATA_PATH="/mnt/sfs_turbo/gyx/data_en/sst2"

LR=${1-0.00005}
GRAD_ACC=${2-1}
SEED=${3-1234}

CONFIG_PATH="${WORKING_DIR}/configs/model/t5_large_config.json"
CKPT_PATH="/mnt/sfs_turbo/gyx/checkpoints/t5-large/t5-MP1/"

SAVE_PATH="${WORKING_DIR}/results/sst2/few-shot-32/at_large_fp32_fix_only_at_rdc_16/lr${LR}_G${GRAD_ACC}/seed${SEED}/"
LOG_FILE="${SAVE_PATH}/log.txt"
DS_CONFIG="${WORKING_DIR}/configs/deepspeed/ds_fp32.json"
TOKENIZER_PATH="${WORKING_DIR}/vocab_en"

PROMPT_CONFIG="${WORKING_DIR}/configs/adapter/at.json"

BATCH_SIZE=2
TRAIN_ITER=-1
EPOCHS=50


OPTS=""
OPTS+=" --model-config ${CONFIG_PATH}"
OPTS+=" --model-parallel-size ${MP_SIZE}"
OPTS+=" --batch-size ${BATCH_SIZE}"
OPTS+=" --gradient-accumulation-steps ${GRAD_ACC}"
OPTS+=" --train-iters ${TRAIN_ITER}"
OPTS+=" --save ${SAVE_PATH}"
OPTS+=" --log-file ${LOG_FILE}"
OPTS+=" --load ${CKPT_PATH}"
OPTS+=" --data-path ${DATA_PATH}"
OPTS+=" --data-ext ${DATA_EXT}"
OPTS+=" --data-name sst2"
OPTS+=" --distributed-backend nccl"
OPTS+=" --lr ${LR}"
OPTS+=" --no-load-optim"
OPTS+=" --lr-decay-style constant"
OPTS+=" --weight-decay 1e-2"
OPTS+=" --clip-grad 1.0"
OPTS+=" --warmup 0.0"
OPTS+=" --tokenizer-path ${TOKENIZER_PATH}"
OPTS+=" --save-interval 6"
OPTS+=" --eval-interval 6"
OPTS+=" --eval-iters 10"
OPTS+=" --log-interval 2"
# OPTS+=" --checkpoint-activations"
# OPTS+=" --deepspeed-activation-checkpointing"
# OPTS+=" --fp16"
OPTS+=" --deepspeed"
OPTS+=" --deepspeed_config ${DS_CONFIG}"
OPTS+=" --do-train"
OPTS+=" --do-valid"
OPTS+=" --seed ${SEED}"
OPTS+=" --adapter-tune"
OPTS+=" --adapter-config ${PROMPT_CONFIG}"
OPTS+=" --epochs ${EPOCHS}"

CMD="python3 -m torch.distributed.launch ${DISTRIBUTED_ARGS} ${WORKING_DIR}/train.py ${OPTS}"

echo ${CMD}
mkdir -p ${SAVE_PATH}
${CMD} 2>&1 | tee ${SAVE_PATH}/train_log