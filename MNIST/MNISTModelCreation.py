import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Flatten, Dense
import json

csv_path = './mnist_dataset.csv'  
df = pd.read_csv(csv_path)

X = df.drop('label', axis=1).values
y = df['label'].values

# Split the data into training and testing (assuming the CSV contains both in order)
# This assumes that the dataset is ordered as in the typical MNIST dataset, with 60,000 training and 10,000 test images
#x_train, x_test = X[:60000], X[60000:]
#y_train, y_test = y[:60000], y[60000:]

model = Sequential([
    Flatten(input_shape=(784,)),  # Note the input shape is now 784, as the images should already be flattened
    Dense(128, activation='relu'),
    Dense(10, activation='softmax')  # Output layer for 10 classes
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

model.fit(X, y, epochs=5)

#test_loss, test_acc = model.evaluate(x_test, y_test, verbose=2)
#print('\nTest accuracy:', test_acc)

model_path = './mnist_model.h5' 
model.save(model_path)
print(f"Model saved to {model_path}")

model_path = './mnist_model.h5'  
model = tf.keras.models.load_model(model_path)
print("Model loaded successfully")

model_weights = {}
for layer in model.layers:
    weights = layer.get_weights()  
    model_weights[layer.name] = [w.tolist() for w in weights] 

weights_json_path = './model_weights.json'
with open(weights_json_path, 'w') as f:
    json.dump(model_weights, f)
print(f"Weights saved to JSON file at {weights_json_path}")