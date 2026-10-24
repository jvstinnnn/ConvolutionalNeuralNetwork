import torch

# Load trained PyTorch weights and biases
network = torch.load("trained_net.pth")

## 1 Signed Bit, 2 Integer Bits, 13 Fractional Bits

FRAC_BITS = 14
SCALE = 2 ** FRAC_BITS      # 16384

MIN_INT16 = -32768
MAX_INT16 = 32767

def fixedpoint_conv(tensor, filename):
    # Float to fixed-point integer
    fixed = torch.round(tensor * SCALE)

    # Checking 16bit overflow
    if fixed.min() < MIN_INT16 or fixed.max() > MAX_INT16:
        raise ValueError(f"Overflow detected in {filename}")

    # Convert to signed 16bit
    fixed = fixed.to(torch.int16)

    # Create mem file
    with open(filename, "w") as file:

        # Flatten multidimensional tensor
        for value in fixed.flatten():

            # PyTorch scalar -> Python integer
            value = int(value.item())

            # 16bit integer 2's compliment
            value = value & 0xFFFF

            # 4bit hex
            file.write(f"{value:04X}\n")

#Conv layers
fixedpoint_conv(network["conv1.weight"], "conv1_weights.mem")
fixedpoint_conv(network["conv1.bias"], "conv1_bias.mem")
fixedpoint_conv(network["conv2.weight"], "conv2_weights.mem")
fixedpoint_conv(network["conv2.bias"], "conv2_bias.mem")

#FC layers
fixedpoint_conv(network["fc1.weight"], "fc1_weights.mem")
fixedpoint_conv(network["fc1.bias"], "fc1_bias.mem")
fixedpoint_conv(network["fc2.weight"], "fc2_weights.mem")
fixedpoint_conv(network["fc2.bias"], "fc2_bias.mem")
fixedpoint_conv(network["fc3.weight"], "fc3_weights.mem")
fixedpoint_conv(network["fc3.bias"], "fc3_bias.mem")

print("Finished exporting weights and biases.")