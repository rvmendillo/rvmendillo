from flask import request
import requests

def verify_captcha():
    response = requests.post('https://www.google.com/recaptcha/api/siteverify', data={'secret': '6Lfq6-QdAAAAAI6KgavwJfqdPq-FdQFoogEngYTv',
                                                                                      'response': request.form['g-recaptcha-response']})
    return response.json()['success']