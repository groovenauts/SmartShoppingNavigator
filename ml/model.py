import tensorflow as tf

def model_fn(features, labels, mode, params):
    with tf.variable_scope("inputs/carts"):
        cart  = tf.reshape(features["cart_history"], [-1, HISTORY_SIZE, NUM_ITEMS])
        cart = tf.layers.conv1d(cart, filters=NUM_ITEMS*2, kernel_size=3, padding="valid", activation=tf.nn.relu)
        cart = tf.contrib.layers.flatten(cart)
    with tf.variable_scope("inputs/season"):
        seasons_table = tf.contrib.lookup.index_table_from_tensor(["spring", "summer", "fall", "winter"])
        season = tf.reshape(tf.one_hot(seasons_table.lookup(features["season"]), 4, on_value=1.0, off_value=0.0), [-1, 4])
    with tf.variable_scope("inputs/time"):
        time_table = tf.contrib.lookup.index_table_from_tensor(["morning", "noon", "evening"])
        time = tf.reshape(tf.one_hot(time_table.lookup(features["time"]), 3, on_value=1.0, off_value=0.0), [-1, 3])
    x = tf.concat([cart, season, time], axis=1)
    with tf.variable_scope("output"):
        logits = tf.layers.dense(inputs=x, units=(NUM_ITEMS+1), activation=None)

    loss = tf.reduce_mean(tf.nn.sparse_softmax_cross_entropy_with_logits(logits=logits, labels=labels))
    eval_metrics = { "accuracy": tf.metrics.accuracy(tf.argmax(logits, 1), labels) }
    optimizer = tf.train.AdamOptimizer(learning_rate=learning_rate)
    update_ops = tf.get_collection(tf.GraphKeys.UPDATE_OPS)
    with tf.control_dependencies(update_ops):
        train_op = optimizer.minimize(loss, global_step=tf.train.get_global_step())
    return tf.estimator.EstimatorSpec(
            mode=mode,
            loss=loss,
            train_op=train_op,
            eval_metric_ops=eval_metrics)
