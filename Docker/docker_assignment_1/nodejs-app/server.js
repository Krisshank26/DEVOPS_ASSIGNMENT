import express from "express" 

const app= express() 

app.use(express.json() ) 

const PORT= 8080 

app.get('/', (req, res )=> 
{ 
    res.send('<h1>Hello friend in Application in Docker Container' ) 
} ) 

app.listen(PORT, ()=> 
{ 
    console.log("Server is listening on PORT: "+ PORT ) 
} ) 