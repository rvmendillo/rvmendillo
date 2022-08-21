from app import app
from flask import render_template, request
from json import loads
from collections import Counter
from nltk.stem import WordNetLemmatizer
from nltk.tokenize import RegexpTokenizer
from nltk.corpus import stopwords
import pickle
import pandas as pd
import os
import liwc
import re

def load_variable(filename):
    with open(filename, 'rb') as file:
        variable = pickle.load(file)
    return variable

class MBTIPersonalityPrediction:
    lemmatizer = WordNetLemmatizer()
    introvert_standard_scaler = load_variable('static/files/introvert.scaler')
    sensing_standard_scaler = load_variable('static/files/sensing.scaler')
    thinking_standard_scaler = load_variable('static/files/thinking.scaler')
    judging_standard_scaler = load_variable('static/files/judging.scaler')
    scaled_introvert_dataset = load_variable('static/files/introvert.scaled')
    scaled_sensing_dataset = load_variable('static/files/sensing.scaled')
    scaled_thinking_dataset = load_variable('static/files/thinking.scaled')
    scaled_judging_dataset = load_variable('static/files/judging.scaled')
    reduced_introvert_dataset = load_variable('static/files/reduced_introvert_rf.features')
    reduced_sensing_dataset = load_variable('static/files/reduced_sensing_rf.features')
    reduced_thinking_dataset = load_variable('static/files/reduced_thinking_rf.features')
    reduced_judging_dataset = load_variable('static/files/reduced_judging_rf.features')
    introvert_model = load_variable('static/files/introvert_rf.model')
    sensing_model = load_variable('static/files/sensing_rf.model')
    thinking_model = load_variable('static/files/thinking_rf.model')
    judging_model = load_variable('static/files/judging_rf.model')
    
    def tokenize(text):
        for match in re.finditer(r'\w+', text, re.UNICODE):
            yield match.group(0)

    def count_liwc(text, parse):
        text_tokens = MBTIPersonalityPrediction.tokenize(text)
        text_counts = Counter(category for token in text_tokens for category in parse(token))
        return text_counts

    def get_lexical_features(file_transcript, dictionary_path='static/files/decoded.dictionary'):
        decoded_dictionary = load_variable(dictionary_path)
        with open('static/files/temporary.dictionary', 'w') as file:
            file.write(decoded_dictionary)
        parse, category_names = liwc.load_token_parser('static/files/temporary.dictionary')
        os.remove('static/files/temporary.dictionary')
        category_names.insert(0, 'WC')
        file_tokens = [token for token in MBTIPersonalityPrediction.tokenize(file_transcript)]
        file_word_count = len(file_tokens)
        file_liwc_count = MBTIPersonalityPrediction.count_liwc(file_transcript, parse)
        file_lexical_df = pd.DataFrame(columns=category_names).append(file_liwc_count, ignore_index=True)
        file_lexical_df['WC'] = file_word_count
        file_lexical_df.fillna(0, inplace=True)
        return file_lexical_df

    def transform_features(file_df, scaled_df, reduced_df, standard_scaler):
        file_df_copy = file_df.copy()
        file_df_copy = file_df_copy[scaled_df.columns[:-1]]
        transformed_features = standard_scaler.transform(file_df_copy)
        transformed_file_df = pd.DataFrame(transformed_features, columns=scaled_df.columns[:-1])
        transformed_file_df = transformed_file_df[reduced_df.columns[:-1]]
        return transformed_file_df

    def lemmatize(text):
        separated_post = text.replace('|||', ' ')
        lowercased_post = separated_post.lower()
        no_links_post = ' '.join([token for token in lowercased_post.split() if 'http' not in token])
        unique_words = list(set(RegexpTokenizer(r"([^\W_0-9]+'*[^\W_0-9]*)").tokenize(no_links_post)))
        no_stopwords_list = [word for word in unique_words if word not in stopwords.words('english')]
        lemmatized_post = ' '.join([MBTIPersonalityPrediction.lemmatizer.lemmatize(word) for word in no_stopwords_list])
        return lemmatized_post
    
    def predict_personality(self, writing):
        lemmatized_user_input = MBTIPersonalityPrediction.lemmatize(writing)
        liwc_user_input_dataset = MBTIPersonalityPrediction.get_lexical_features(lemmatized_user_input)
        transformed_introvert_dataset = MBTIPersonalityPrediction.transform_features(liwc_user_input_dataset, MBTIPersonalityPrediction.scaled_introvert_dataset, MBTIPersonalityPrediction.reduced_introvert_dataset, MBTIPersonalityPrediction.introvert_standard_scaler)
        transformed_sensing_dataset = MBTIPersonalityPrediction.transform_features(liwc_user_input_dataset, MBTIPersonalityPrediction.scaled_sensing_dataset, MBTIPersonalityPrediction.reduced_sensing_dataset, MBTIPersonalityPrediction.sensing_standard_scaler)
        transformed_thinking_dataset = MBTIPersonalityPrediction.transform_features(liwc_user_input_dataset, MBTIPersonalityPrediction.scaled_thinking_dataset, MBTIPersonalityPrediction.reduced_thinking_dataset, MBTIPersonalityPrediction.thinking_standard_scaler)
        transformed_judging_dataset = MBTIPersonalityPrediction.transform_features(liwc_user_input_dataset, MBTIPersonalityPrediction.scaled_judging_dataset, MBTIPersonalityPrediction.reduced_judging_dataset, MBTIPersonalityPrediction.judging_standard_scaler)
        introvert_prediction = 'I' if MBTIPersonalityPrediction.introvert_model.predict(transformed_introvert_dataset)[0] == 1 else 'E'
        sensing_prediction = 'S' if MBTIPersonalityPrediction.sensing_model.predict(transformed_sensing_dataset)[0] == 1 else 'N'
        thinking_prediction = 'T' if MBTIPersonalityPrediction.thinking_model.predict(transformed_thinking_dataset)[0] == 1 else 'F'
        judging_prediction = 'J' if MBTIPersonalityPrediction.judging_model.predict(transformed_judging_dataset)[0] == 1 else 'P'
        mbti_personality = introvert_prediction + sensing_prediction + thinking_prediction + judging_prediction
        return mbti_personality

@app.route('/mbti_personality_predictor', methods=['GET', 'POST'])
def mbti_personality_predictor():
    project = loads(request.args['project'])
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
