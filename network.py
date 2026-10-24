import numpy as np
from PIL import Image

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

image, label = train_data[0]
#print(image.size())
#torch.size([1, 28, 28]) <-- grayscale images of 28 by 28

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
        x = self.pool(F.relu(self.conv1(x))) # Conv1 -> ReLU1 -> MaxPool1 -> Result1
        x = self.pool(F.relu(self.conv2(x))) # Conv2 -> ReLU2 -> MaxPool2 -> Result2
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

def main():
    net = CNN()
    loss_function = nn.CrossEntropyLoss()
    optimizer = optim.SGD(net.parameters(), lr = 0.001, momentum = 0.9)

    for epoch in range(30):
        print(f'Training epoch: {epoch}...')
        running_loss = 0.0

        for _, data in enumerate(train_loader):
            inputs, labels = data
            optimizer.zero_grad()
            outputs = net(inputs)
            loss = loss_function(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item()

        print(f'Loss: {running_loss / len(train_loader):.4f}')

    torch.save(net.state_dict(), 'trained_net.pth')

if __name__ == "__main__":
    main()