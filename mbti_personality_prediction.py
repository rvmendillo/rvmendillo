from app import app
from flask import render_template, request
from json import loads
import mbti_personality_prediction as mbti

@app.route('/mbti_personality_prediction', methods=['GET', 'POST'])
def mbti_personality_prediction():
    project = loads(request.args['project'])
    paragraph_to_predict = loads(request.args['paragraph_to_predict'])
    predictor = mbti.MBTIPersonalityPrediction()
    mbti_type = predictor.predict_personality(paragraph_to_predict)

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'],
                                           output=mbti_type)