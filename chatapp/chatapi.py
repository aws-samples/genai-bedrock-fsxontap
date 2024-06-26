import json
import time
import streamlit as st
import random
import requests
import os

from config import config
from typing import Tuple, Dict

INIT_MESSAGE = {"role": "assistant",
                "content": "Hi! I'm Claude on Bedrock. I can help you with quries on your FSxN data. \n What would you like to know?",
                "documents": []}

def new_chat() -> None:
    st.session_state["sessionId"] = str(random.randint(1, 1000000))
    st.session_state["messages"] = [INIT_MESSAGE]
    st.session_state["langchain_messages"] = []

def set_page_config() -> None:
    st.set_page_config(page_title="🤖 Chat with your FSxN data", layout="wide")
    st.title("🤖 Chat with your FSxN data")

def render_sidebar() -> Tuple[Dict, int, str]:
    with st.sidebar:           
        # st.markdown("## Inference Parameters")
        model_name_select = st.selectbox(
            'Model',
            list(config["models"].keys()),
            key=f"{st.session_state['sessionId']}_Model_Id",
        )

        st.session_state["model_name"] = model_name_select

        model_config = config["models"][model_name_select]

        metadata = st.text_input(
                    'User (SID) filter search',
                    key=f"{st.session_state['sessionId']}_Metadata",
                )  
        with st.container():
            col1, col2 = st.columns(2)
            with col1:   
                temperature = st.slider(
                    "Temperature",
                    min_value=0.0,
                    max_value=1.0,
                    value=model_config.get("temperature", 1.0),
                    step=0.1,
                    key=f"{st.session_state['sessionId']}_Temperature",
                )   
            with col2:  
                max_tokens = st.slider(
                    "Max Token",
                    min_value=0,
                    max_value=4096,
                    value=model_config.get("max_tokens", 4096),
                    step=8,
                    key=f"{st.session_state['sessionId']}_Max_Token",
                )
        with st.container():
            col1, col2 = st.columns(2)
            with col1:
                top_p = st.slider(
                    "Top-P",
                    min_value=0.0,
                    max_value=1.0,
                    value=model_config.get("top_p", 1.0),
                    step=0.01,
                    key=f"{st.session_state['sessionId']}_Top-P",
                )
            with col2:
                top_k = st.slider(
                    "Top-K",
                    min_value=1,
                    max_value=model_config.get("max_top_k", 500),
                    value=model_config.get("top_k", 500),
                    step=5,
                    key=f"{st.session_state['sessionId']}_Top-K",
                )
        with st.container():
            col1, col2 = st.columns(2)
            with col1:
                memory_window = st.slider(
                    "Memory Window",
                    min_value=0,
                    max_value=10,
                    value=model_config.get("memory_window", 10),
                    step=1,
                    key=f"{st.session_state['sessionId']}_Memory_Window",
                )
        with st.container():
            with st.expander("Chat URL"):
                form = st.form("chat_form")
                url = form.text_input("Chat Url",os.environ['CHAT_URL'])
                form.form_submit_button("Submit")
                if not url:
                    st.error("Please enter a valid URL")

    st.sidebar.button("New Chat", on_click=new_chat, type="primary")

    model_kwargs = {
        "temperature": temperature,
        "top_p": top_p,
        "top_k": top_k,
        "max_tokens": max_tokens,
    }


    return model_config['model_id'],model_kwargs, memory_window, metadata, url 

def init_conversationchain(prompt, bedrock_model_id, model_kwargs, metadata, memory_window, url):
    try:
        if not metadata:
            metadata = "NA"

        payload = json.dumps({
            "session_id": st.session_state["sessionId"],
            "prompt": prompt,
            "bedrock_model_id": bedrock_model_id,
            "model_kwargs": model_kwargs,
            "metadata": metadata,
            "memory_window": memory_window
        })

        headers = {
            'Content-Type': 'application/json'
        }
        
        print(payload)
        result = requests.post(url, headers=headers, data=payload)
        print(result.text)

        if result.status_code == 200:
            answer = json.loads(result.text).get("body")
            return answer
        else:
            st.error(f"Request failed with status code: {result.status_code}",icon="🚨")
            return None
    except Exception as e:
        st.error(f"An error occurred: {str(e)}",icon="🚨")
        return None

def stream_data(response):
    for word in response.split(" "):
        yield word + " "
        time.sleep(0.02)

def main():
    history = []

    set_page_config() 
    # Generate a unique widget key only once
    if "sessionId" not in st.session_state:
        st.session_state["sessionId"] = str(random.randint(1, 1000000))

    bedrock_model_id, model_kwargs, memory_window, metadata, url = render_sidebar()
    
    if "messages" not in st.session_state:
        st.session_state.messages = []
        st.session_state["messages"] = [INIT_MESSAGE]
    
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
            if message["documents"]:
                with st.expander("Sources"):
                    for source in set(message["documents"]):
                        st.write(f"Source: {str(source)}")

    # User-provided prompt
    prompt = st.chat_input()
 
    if prompt:
        with st.chat_message("user"):
            st.markdown(prompt)
        # Add user message to chat history
        st.session_state.messages.append({"role": "user", "content": prompt, "documents": []})
        
        # with st.spinner("Thinking..."):
        response = init_conversationchain(prompt,bedrock_model_id,model_kwargs,metadata,memory_window,url)

        # Add assistant message to chat history
        if response is not None:
            with st.chat_message("assistant"):
                st.write_stream(stream_data(response["answer"]))
                with st.expander("Sources"):
                    for source in set(response["documents"]):
                        st.write(f"Source: {str(source)}")
            st.session_state.messages.append({"role": "assistant", "content": response["answer"], "documents": response["documents"]})


if __name__ == "__main__":
    main()
