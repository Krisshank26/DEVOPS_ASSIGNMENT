from flask import Flask 

app= Flask(__name__ ) 

@app.route('/' ) 
def hello_world(): 
    return "Hello World from Docker Container Here " 

if __name__== "__main__": 
    # The app must listen on 0.0.0.0 so it can accept internal requests via Docker 
    app.run(host="0.0.0.0", port= 5000 ) 