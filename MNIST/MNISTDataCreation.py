import numpy as np
import pandas as pd
import tensorflow as tf

mnist = tf.keras.datasets.mnist
(x_train, y_train), (x_test, y_test) = mnist.load_data()

x_train, x_test = x_train / 255.0, x_test / 255.0

x = np.concatenate((x_train, x_test), axis=0)
y = np.concatenate((y_train, y_test), axis=0)

x_flattened = x.reshape(x.shape[0], -1)

df = pd.DataFrame(x_flattened)
df['label'] = y

df = df[:19000]

df.to_csv('./mnist_dataset.csv', index=False)
