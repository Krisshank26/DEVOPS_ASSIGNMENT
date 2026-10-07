FROM node:20-alpine 

COPY package*.json ./ 

RUN npm install 

COPY . . 

EXPOSE 8080 

CMD ["node", "server.js" ] 