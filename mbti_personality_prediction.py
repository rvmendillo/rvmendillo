from app import app
from flask import render_template, request
from json import loads
from mbti_personality_prediction import MBTIPersonalityPrediction

@app.route('/mbti_personality_prediction', methods=['GET', 'POST'])
def mbti_personality_prediction():
    paragraph_to_predict = loads(request.args['paragraph_to_predict'])
    predictor = MBTIPersonalityPrediction()
    mbti_type = predictor.predict_personality(paragraph_to_predict)

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'],
                                           output=mbti_type)