from flask import Flask, request, jsonify
from pymongo import MongoClient
from datetime import datetime

#create app
app = Flask(__name__)

uri = "mongodb+srv://myuser:helloworld@keepintouch.y1uvq.mongodb.net/?retryWrites=true&w=majority&appName=KeepInTouch"

#Global DataStruct dictionary with {"contact":"recent date of contact"} if build out multiple users (list of recency dicts)
contact_cache = dict()


@app.route('/log', methods=['POST'])
def log_info():

    print('---------------')

    # Get the JSON data from the request body
    data = request.json
    if not data:
        return jsonify({'error': 'No data recived'}), 400

    if 'recent_contact' not in data or 'owner_id' not in data or 'current_date' not in data:
        return jsonify({'error': 'Data recieved in wrong format'}), 400
    # Extract the name from the JSON data

    recent_contact = data['recent_contact']
    owner_id = data['owner_id']
    date = data['current_date']

    if 'birthday' in data:
        birthday = data['birthday']
    else: 
        birthday = None

    # Call the update function to increment the counter
    if not query_cache(recent_contact,date):
        update_server(recent_contact,date,birthday)

    # Return a response
    return jsonify({'message': f'Name "{recent_contact}" received successfully', 'last_contact': date}), 200


def query_cache(name, last_contact):
    
    if name in contact_cache.keys():
        if are_same_day(contact_cache[name], last_contact):
            print("already queried server today at (",contact_cache[name],") for", name)
            return True
        
    contact_cache[name] = last_contact
    return False



def are_same_day(date_str1, date_str2):
    # Define the format of the input date strings
    date_format = "%m/%d/%y, %I:%M:%S %p %Z"
    
    # Parse the date strings into datetime objects
    date1 = datetime.strptime(date_str1, date_format)
    date2 = datetime.strptime(date_str2, date_format)
    
    # Compare the date parts of the datetime objects
    return date1.date() == date2.date()


def update_server(name, last_contact, birthday=None):

    print("Sending Update to Server for ", name)

    database = client.get_database("KeepInTouch")
    user_collection = database.get_collection("user01")

    query_filter = {"name":name}

    if not check_exists(query_filter, user_collection):
        new_contact = [{"name": name,"last_contact":last_contact,"birthday":birthday}]       
        result = user_collection.insert_many(new_contact)
        print("New Contact Made")

    else:
        updated_values = {"last_contact":last_contact, "birthday":birthday}

        user_collection = database.get_collection("user01")
        result = user_collection.update_many(query_filter, {'$set': updated_values})
        print("Contact Updated")


def check_exists(query_filter, user_collection):
    document = user_collection.find_one(query_filter)
    # print("Already exists: ", (document is not None))
    return document is not None



if __name__ == '__main__':
    client = MongoClient(uri)
    app.run(host='0.0.0.0', port=8080, debug=True)
