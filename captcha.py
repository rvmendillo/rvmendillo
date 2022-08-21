from flask import request
import requests
import os

def verify_captcha():
    response = requests.post('https://www.google.com/recaptcha/api/siteverify', data={'secret': os.environ['CAPTCHA_SECRET'],
                                                                                      'response': request.form['g-recaptcha-response']})
    return response.json()['success']