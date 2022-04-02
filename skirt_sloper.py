import matplotlib.pyplot as plt
import numpy as np

class Dimension:
    def __init__(self, full):
        self.full = full
        self.half = full / 2
        self.fourth = full / 4
        self.twelfth = full / 12

class Dart:
    def __init__(self, depth, length):
        self.depth = depth
        self.length = length

def line(x1, y1, x2, y2):
    plt.plot([x1*cm, x2*cm], [y1*cm, y2*cm])

def curve(point1, point2, rotate=False):
    a = (point2[1]*cm - point1[1]*cm)/(np.cosh(point2[0]*cm) - np.cosh(point1[0]*cm))
    b = point1[1]*cm - a*np.cosh(point1[0]*cm)
    x = np.linspace(point1[0]*cm, point2[0]*cm, 100)
    y = a*np.cosh(x) + b
    if not rotate:
        plt.plot(x, y)
    else:
        y_middle = np.linspace(point1[1]*cm, point2[1]*cm, 100)
        plt.plot(x, y_middle+(y_middle-y)[::-1])