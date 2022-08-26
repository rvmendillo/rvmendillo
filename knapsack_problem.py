from app import app
from flask import render_template, request, jsonify
from json import loads
from random import choices, randint, randrange, random, shuffle
from collections import namedtuple
from functools import partial
import datetime

generate_genome = lambda length: choices([0, 1], k=length)
generate_population = lambda size, length: [generate_genome(length) for _ in range(size)]
Item = namedtuple("Item", ["name", "value", "time"])

def fitness(genome, items, time_limit):
    time = 0
    value = 0
    for i, item in enumerate(items):
        if genome[i] == 1:
            time += item.time
            value += item.value
            if time > time_limit:
                return 0
    return value

selection_pair = lambda population, fitness: choices(population=population,
                                                     weights=[fitness(genome) for genome in population],
                                                     k=2)

def single_point_crossover(a, b):
    length = len(a)
    if length < 2:
        return a, b
    p = randint(1, length-1)
    return a[0:p] + b[p:], b[0:p] + a[p:]

def mutation(genome, probability=0.5):
    index = randrange(len(genome))
    genome[index] = genome[index] if random() > probability else abs(genome[index]-1)
    return genome

def run_evolution(population,
                  fitness,
                  fitness_limit,
                  generation_limit):
    for i in range(generation_limit):
        population = sorted(population,
                            key=lambda genome: fitness(genome),
                            reverse=True)
        if fitness(population[0]) >= fitness_limit:
            break
        next_generation = population[0:2]
        for j in range(int(len(population)/2) - 1):
            parents = selection_pair(population, fitness)
            offspring_a, offspring_b = single_point_crossover(parents[0], parents[1])
            offspring_a = mutation(offspring_a)
            offspring_b = mutation(offspring_b)
            next_generation += [offspring_a, offspring_b]
        population = next_generation
    population = sorted(population,
                        key=lambda genome: fitness(genome),
                        reverse=True)
    return population, i

genome_to_items = lambda genome, items: [item.name for i, item in enumerate(items) if genome[i] == 1]

@app.route('/knapsack_problem', methods=['GET', 'POST'])
def knapsack_problem():
    project = loads(request.args['project'])
    items = [Item(item[0], int(item[1]), int(item[2])) for item in loads(request.args['items'])]
    weight_limit = loads(request.args['weight_limit'])

    start = datetime.datetime.now()
    population, generations = run_evolution(generate_population(5, len(items)),
                                            fitness=partial(fitness, items=items, time_limit=weight_limit),
                                            fitness_limit=5000,
                                            generation_limit=10000)
    end = datetime.datetime.now()
    evolution_time = end - start
    optimal_combination = genome_to_items(population[0], items)
    total_weight = sum([test_item.time for item in optimal_combination for test_item in items if item == test_item.name])

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'],
                                           generations=generations,
                                           evolution_time=evolution_time,
                                           total_weight=total_weight,
                                           items=items,
                                           output=optimal_combination)