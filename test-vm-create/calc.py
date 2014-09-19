import sys
import numpy as np

numbers = []
if __name__ == "__main__":
    for line in sys.stdin:
        numbers.append(float(line))

print 'cnt',len(numbers),'sum',np.sum(numbers),'mean',np.mean(numbers),'std',np.std(numbers),'max',np.max(numbers),'min',np.min(numbers)
