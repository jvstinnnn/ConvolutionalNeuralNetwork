import numpy as np
from PIL import Image, ImageOps

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim

import torchvision
import torchvision.transforms as transforms

transform = transforms.Compose([
    transforms.ToTensor(),
    #Since MNIST is grayscale, only need 1 channel
    #if RGB --> transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    transforms.Normalize((0.5), (0.5))
])

#Loading MNIST digit dataset from PyTorch library
train_data = torchvision.datasets.MNIST(root='./data', train = True, transform = transform, download = True)
test_data = torchvision.datasets.MNIST(root='./data', train = False, transform = transform, download = True)

train_loader = torch.utils.data.DataLoader(train_data, batch_size = 32, shuffle = True, num_workers = 2)
test_loader = torch.utils.data.DataLoader(test_data, batch_size = 32, shuffle = True, num_workers = 2)

class_names = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']

class CNN(nn.Module):
    def __init__(self):
        super().__init__()

        self.conv1 = nn.Conv2d(1, 12, 3) # ((input_size-kernal_size)/stride)+1 --> ((28-3)/1)+1 = 26 --> (12, 26, 26)
        self.pool = nn.MaxPool2d(2, 2) # (12, 13, 13)
        self.conv2 = nn.Conv2d(12, 24, 3) # (24, 11, 11) -> (24, 5, 5), floor it -> flatten
        self.fc1 = nn.Linear(24 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, 10) #10 because number of classes

    def forward(self, x):
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

new_transform = transforms.Compose([
    transforms.Grayscale(num_output_channels=1),
    transforms.Resize((28,28)),
    transforms.ToTensor(),
    transforms.Normalize((0.5), (0.5))
])

def load_image(path):
    image = Image.open(path)
    image = new_transform(image)
    image = image.unsqueeze(0)
    return image

def main():
    net_test = CNN()
    net_test.load_state_dict(torch.load('trained_net.pth'))
    correct = 0
    total = 0
    net_test.eval()

    """
    path = ['mine.png','mine2.png','mine3.png']
    images = [load_image(img) for img in path]

    with torch.no_grad():
        for image in images:
            outputs = net_test(image)
            _, predicted = torch.max(outputs, 1)
            print(f'Prediction: {class_names[predicted.item()]}')
    """
    
### Used to get numeric accuracy    
    with torch.no_grad():
        for data in test_loader:
            images, labels = data
            outputs = net_test(images)
            _, predicted = torch.max(outputs, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

    accuracy = 100 * correct / total
    print(f'Accuracy = {accuracy}%')

if __name__ == "__main__":
    main()