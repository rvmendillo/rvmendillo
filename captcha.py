from flask import request
import requests
import os

def verify_captcha(function):
    def wrapper(*args, **kwargs):
        response = requests.post('https://www.google.com/recaptcha/api/siteverify', data={'secret': os.environ['CAPTCHA_SECRET'],
                                                                                          'response': request.form['g-recaptcha-response']})
        if response.json()['success']:
            return function(*args, **kwargs)
        return 'reCAPTCHA validation failed.'
    return wrapper