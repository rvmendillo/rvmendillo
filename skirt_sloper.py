from app import app
from flask import render_template, request
import matplotlib.pyplot as plt
import numpy as np

cm = 1/2.54

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

@app.route('/skirt_sloper', methods=['GET', 'POST'])
def skirt_sloper():
    if request.method == 'POST':
        response = requests.post('https://www.google.com/recaptcha/api/siteverify', data={'secret': '6Lfq6-QdAAAAAI6KgavwJfqdPq-FdQFoogEngYTv',
                                                                                          'response': request.form['g-recaptcha-response']})
        if response.json()['success']:
            waist = Dimension(float(request.form['waist']))
            waist_ease = Dimension(float(request.form['waist_ease']))
            hip = Dimension(float(request.form['hip']))
            hip_height = Dimension(float(request.form['hip_height']))
            hip_ease = Dimension(float(request.form['hip_ease']))
            length = Dimension(float(request.form['length']))
            setattr(waist, 'back', waist.fourth - 0.75 + waist_ease.fourth)
            setattr(waist, 'front', waist.fourth + 0.75 + waist_ease.fourth)
            setattr(hip, 'back', hip.fourth - 0.5 + hip_ease.fourth)
            setattr(hip, 'front', hip.fourth + 0.5 + hip_ease.fourth)
            back_dart = Dart(float(request.form['back_dart']), hip_height.full * 0.75)
            front_dart = Dart(float(request.form['front_dart']), hip_height.full * 0.5)
            side_seam_balance = ((hip.half+hip_ease.half) - (waist.half+waist_ease.half) - (front_dart.depth+back_dart.depth)) / 2
            setattr(hip, 'total', hip.back + hip.front)

            plt.figure(figsize=(hip.total*cm, (length.full+1.5)*cm))

            # Back
            line(0, -1.5, 0, -(1.5+length.full)) # 1
            line(0, -1.5, hip.back, -1.5) # 3
            line(0, -(1.5+hip_height.full), hip.total, -(1.5+hip_height.full)) # 4
            line(0, -(1.5+length.full), hip.total, -(1.5+length.full)) # 4
            line(hip.back, -(1.5+hip_height.full), hip.back, 0) # 6
            line(hip.back, -(1.5+hip_height.full), hip.back, -(1.5+length.full)) # 6
            line(hip.back-side_seam_balance, 0, hip.total, 0) # 7
            line((hip.twelfth*2+back_dart.depth)/2, -1.5, (hip.twelfth*2+back_dart.depth)/2, -(1.5+hip_height.full)) # 10
            curve([hip.twelfth/2, -1.5], [hip.back-side_seam_balance, 0]) # 12
            line((hip.twelfth*2+back_dart.depth)/2, -(1.5+back_dart.length), hip.twelfth, -1.5) # 14
            line((hip.twelfth*2+back_dart.depth)/2, -(1.5+back_dart.length), hip.twelfth+back_dart.depth, -1.5) # 14

            # Front
            line(hip.total, -(1.5+length.full), hip.total, -(1.5-0.8)) # 2
            line(hip.total, -(1.5-0.8), hip.total-hip.front, -(1.5-0.8)) # 3
            line(hip.total, -(1.5-0.8), hip.total-hip.twelfth, -(1.5-0.8)) # 4
            line(hip.total-hip.twelfth, -(1.5-0.8), hip.total-hip.twelfth-front_dart.depth, -(1.5-0.8)) # 5
            line(((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5-0.8), ((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5+hip_height.full)) # 6
            curve([((hip.total)+(hip.total-hip.twelfth))/2, -(1.5-0.8)], [hip.back+side_seam_balance, 0], rotate=True) # 8
            line(((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5+front_dart.length), hip.total-hip.twelfth, -(1.5-0.8)) # 10
            line(((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5+front_dart.length), hip.total-hip.twelfth-front_dart.depth, -(1.5-0.8)) # 10

            # Trace
            curve([hip.back, -(1.5+back_dart.length), ((-(1.5+back_dart.length))+((-(1.5+back_dart.length))/2))/2], [hip.back-side_seam_balance, 0]) # 1
            curve([hip.back, -(1.5+back_dart.length), ((-(1.5+back_dart.length))+((-(1.5+back_dart.length))/2))/2], [hip.back+side_seam_balance, 0], rotate=True) # 2

            plt.subplots_adjust(top=1, bottom=0, right=1, left=0, hspace=0, wspace=0)
            plt.margins(0, 0)
            plt.yticks(np.arange(-(length.full+1.5)*cm, 0, 1.0))
            plt.xticks(np.arange(0, (hip.total+1)*cm, 1.0))

            temporary_file = BytesIO()
            plt.savefig(temporary_file, format='pdf', dpi=int(request.form['dpi']), bbox_inches='tight', pad_inches=0)
            base64_string = b64encode(temporary_file.getvalue())
            return render_template('skirt_sloper.html', base64_string=base64_string.decode())
        else:
            return 'reCAPTCHA validation failed.'
    return render_template('skirt_sloper.html')
