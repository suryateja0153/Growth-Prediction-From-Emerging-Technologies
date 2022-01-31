# Growth Prediction from Emerging Technologies

## Problem Statement

The topic of this research project is to predict Emerging technologies from the Gartner reports based on similarity analysis conducted on a companies financials like 10K reports and from platforms like YouTube where information is being shared form one node to another.

**Research Idea**

![](Media/Image1.jpg)

## Literature Review
The principal goal of our literature review is to identify specific sources of financial and conversational text data which can then be mined for insights. For this study we chose SEC 10K data for all the businesses that fall in the Information technology domain. For the growth estimation aspect, we have chosen YouTube as data sourcing could be done via the API. The key emergence technology terms were sourced from Gartner’s Hype cycle for emerging technologies reports from the past six years (2015-2020).

## Building Corpus

The starting dataset for this analysis comes from the decision to include a set of businesses in a specific domain. Since we are going by the Gartner Hype Cycle to decide on the emerging technologies, we have chosen to select about 73 businesses in the IT/Technology domain.

Part - 1 of the dataset can be found here: [List of Companies](Data/)

The next step of the data gathering process is to write a piece of code to Web Scrape text data from the Securities and Exchange Commission (SEC) 10K reports.

**Code Snippets from SEC 10K Scraper**

```
def dfSec10k(cik_inp):
    # set the central index key
    cik = cik_inp
    
    # pass the main url from SEC
    url = 'https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=' + cik + '&type=10-k&dateb=&owner=exclude&count=40&search_text='

    # grab the html
    try:
        page = urllib.request.urlopen(url)
    except:
        print("An error occured.")

    soup = BeautifulSoup(page, "html.parser")

    list_td = []
    for item in soup.find_all('td',class_=["small",""]):
        list_td.append(item.text)

    list_td_2 = []
    for item1 in soup.find_all('td',class_=["small",""]):
        for i in item1.find_next('td'):
            list_td_2.append(i)

    df = pd.DataFrame(list_td)
    df1 = pd.DataFrame(list_td_2)

    df.columns = ['table']
    df1.columns = ['date']

    result = pd.concat([df, df1], axis=1)

    # Data cleanup step - 1
    result['date'] = result['date'].astype(str)
    result['date'] = pd.to_datetime(result['date'])
    result['year'] = pd.DatetimeIndex(result['date']).year
    del result['date']
    
    # Data cleanup step - 2
    result['table'] = result['table'].astype(str) 
    result['table'] = result['table'].str.replace(' ', '').str.replace('[', '').str.replace(']', '').str.replace(',', '').str.replace('  ', '')
    result['table'] = result['table'].str.replace('(', '').str.replace(')', '').str.replace('-', '',2).str.replace('KB', '')

    result['table'] = result['table'].str.replace('AnnualreportSection13and15d', '').str.replace('Amend', '').str.replace('notSKItem405', '')
    result['table'] = result['table'].str.replace('34Act', '').str.replace('Size', '').str.replace('MB', '').str.replace('SKItem405', '')

    result['table'] = result['table'].str.replace('AnnualreportSections13and15d', '').str.replace('Accno', '').str.replace(':', '',1)

    result['acc_no'] = result['table'].str[:20]
    del result['table']
    
    index_check = []
    for index, row in result.iterrows():
        if row['acc_no'][0:2] == '00':
            index_check.append(index)

    result = result.iloc[index_check].reset_index(drop=True)

    # Data cleanup step - 3
    result['acc_no2'] = result['acc_no'].str.replace('-', '')
    
    result = result.drop_duplicates(subset='year', keep="first")
    result = result.reset_index(drop=True)
    
    result_r11 = result.head(11)
    result_r11
    
    # URL filing link extraction
    df_furl = []

    for x,y in result_r11.iterrows():
        # URL extraction step - 1
        acc_1 = y['acc_no']
        acc_2 = y['acc_no2']

        url_2 = 'https://www.sec.gov/Archives/edgar/data/'+cik+'/'+acc_2+'/'+acc_1+'-index.htm'

        try:
            page_1 = urllib.request.urlopen(url_2)
        except:
            print("An error occured.")

        soup_1 = BeautifulSoup(page_1, "html.parser")
        company_page = [item_page.get_text('\n',strip=True) for item_page in soup_1.select("div.formGrouping")][1]
        company_page = str(company_page)

        r = requests.get(url_2)
        df_table = pd.read_html(r.text)
        df_tp = df_table[0]
        del df_tp['Seq']
        del df_tp['Type']
        del df_tp['Size']
        df_tp = df_tp.astype(str)
        df_tp['Document'] = df_tp['Document'].str.replace(' iXBRL', '')

        # URL extraction step - 2
        doc = df_tp['Document'].iloc[-1]

        url_3 = 'https://www.sec.gov/Archives/edgar/data/'+cik+'/'+acc_2+'/'+doc
        df_furl.append(url_3)
        
    # Text URL output to dataframe
    df_furl
    df_out = pd.DataFrame(df_furl, columns=["final_url"])

    result_r11["final_url"] = df_out["final_url"]
    del result_r11['acc_no2']
    result_r11
    
    return result_r11
```

```
def pullTextAll(link):
    URL_text = str(link)

    # Grab the response
    responses = requests.get(URL_text)

    # Parse the response (the XML flag works better than HTML for 10Ks)
    souper = BeautifulSoup(responses.content, 'lxml')

    text_b = []
    text_r = []
    for filing_document in souper.find_all('document'):
        document_type = filing_document.type.find(text=True, recursive=False).strip()

        if document_type == "10-K":
            text = filing_document.find('text').extract().text

            text = re.sub('\n', ' ', text)
            text = re.sub('\xa0', ' ', text)
            matches = list(re.finditer(re.compile('I[tT][eE][mM] [0-9][a-zA-Z]*\s*[.|:|-]\s*'), text))

            # Business section
            try:
                start_b = max([i for i in range(len(matches)) if ((matches[i][0].upper().replace(" ","") == 'ITEM1.')|
                               (matches[i][0].upper().replace(" ","") == 'ITEM1:')|
                               (matches[i][0].upper().replace(" ","") == 'ITEM1-'))])
                end_b = start_b+1
                start_b = matches[start_b].span()[1]
                end_b = matches[end_b].span()[0]
                text_b = text[start_b:end_b]
            except:
                text_b = None
                
            # Risk section
            try:
                start_r = max([i for i in range(len(matches)) if ((matches[i][0].upper().replace(" ","") == 'ITEM1A.')|
                               (matches[i][0].upper().replace(" ","") == 'ITEM1A:')|
                               (matches[i][0].upper().replace(" ","") == 'ITEM1A-'))])
                end_r = start_r+1
                start_r = matches[start_r].span()[1]
                end_r = matches[end_r].span()[0]
                text_r = text[start_r:end_r]
            except:
                text_r = None

    return text_b, text_r
```

Part - 2 of the dataset to store SEC data as spreadsheets here: [SEC 10K Text Data](Data/Temp_Files_2)

Building a Text Corpus is the next step which is done and saved here:

**Code Snippet for Building Corpus**

```
for rows in temp:
    df = pd.read_excel('C:/Users/surya/Downloads]/Temp_Files_2/' + rows + '.xlsx', sheet_name='Sheet1', index=0)

    del df['year']
    del df['final_url']

    if (df.columns[0] == 'acc-no'):
        df.rename(columns={'acc-no': 'acc_no'}, inplace=True)

    selected_columns1 = df[["acc_no","text_business"]]
    df1 = selected_columns1.copy()

    selected_columns2 = df[["acc_no","text_risk"]]
    df2 = selected_columns2.copy()

    file = 'C:/Users/surya/Downloads/Text_Corpus/' + rows + '/{}.txt'
    for i, ref in df1.iterrows():
        try:
            with open(file.format(ref['acc_no']+'_Business'), 'w') as f:
                f.write(str(ref['text_business']))
        except:
            break

    for i1, ref1 in df2.iterrows():
        try:
            with open(file.format(ref1['acc_no']+'_Risk'), 'w') as f1:
                f1.write(str(ref1['text_risk']))
        except:
            break
```

Part - 3 of the process can be found here: [SEC 10K Corpus](Data/Text_Corpus)

Now, we need to extract YouTube data for which we use the API and extract the data as text.

**Code Snippet to Extract YouTube Data by ETL Method**

```
import json
import requests
import os
import urllib.request
import xml.etree.ElementTree as ET
from bs4 import BeautifulSoup
global brokenstr


def getpage(a):
    nextpage=a
    return nextpage

def getid(m):
    ext=[]
    for i in range(0,len(m)):
        ext.append(m[i]['id'] ['videoId'])
    return ext
def geturl(b):
    p="pageToken="+ b+"&"
    newurl=part0+part1+p+part2+part3+begin_year+part4+end_year+part5+part6
    return newurl


keywords = ["Augmented Data"]
            
for keyword in keywords:

    ext=[]
    lst1=[]

    userquery=keyword
    get_begin_year='2017'
    get_end_year='2018'
    part0="https://www.googleapis.com/youtube/v3/search?"
    part1="part=snippet&maxResults=25&"
    part2="q="+ str(userquery)
    part3="&type=video&videoCaption=closedCaption&publishedAfter="
    begin_year=str(get_begin_year)
    part4="-01-01T00:00:00Z&publishedBefore="
    end_year=str(get_end_year)
    part5="-01-01T00:00:00Z&fields=items(id(channelId%2CvideoId))%2CnextPageToken%2CprevPageToken"
    # Change this line with your YouTube Data API Key
    part6="&key=AIzaSyBEZ73MUbzufi-L6K5P9eJkJbu8-bcagPA"

    # Surya: AIzaSyBEZ73MUbzufi-L6K5P9eJkJbu8-bcagPA
    # Darya: AIzaSyBSUE45QS_OUdiWvvgmUIcs6nTiGmcwuRo
    URL=str(part0+part1+part2+part3+begin_year+part4+end_year+part5+part6)
    page = requests.get(URL)
    
    mystring=str(page.content.decode("utf-8"))
    mydict = json.loads(mystring)
    ext=getid(mydict['items'])
    lst1=lst1+ext
    
    
    for i in range(0,5):
        try:
            ext1=[]
            newurl=geturl(mydict['nextPageToken'])
            page = requests.get(newurl)
            mystring=str(page.content.decode("utf-8"))
            mydict = json.loads(mystring)
            ext1=getid(mydict['items'])
            lst1.extend(ext1)
        except:
            continue
    
    path="C:/Users/surya/Downloads/YT_Corpus [All]/YT_Corpus [2017-2018]/"+keyword
    os.makedirs(path)
    
    for k in range(0,len(lst1)):
        vid=lst1[k]
        myurl="https://www.youtube.com/get_video_info?&video_id="
        url=myurl+vid
        # Change this line with the Windows path to your corpus folder
        filename=vid+".txt"
        actual_path=path+"/"+filename
        with urllib.request.urlopen(url) as response:
            k = response.read()
        a=k.decode("utf-8")
        a=a[a.find("captionTracks"):].replace("%22",'"').replace("%3A",":").replace("%2C",",").replace("%7B","{").replace("%7D","}").replace("%28","(").replace("%29",")").replace("%3D","=").replace("%3F","?").replace("%2F","/").replace("%5C",'\\').replace("u0026","&").replace("%25","%")
        a=a.replace("%2C",",").replace("\\","")
        mylst1=a.split(",")
        lcode=[]
        for i in range(0,len(mylst1)):
            mylst1[i]=mylst1[i].replace('"',"")
            if "languageCode:en" in mylst1[i]:
                lcode.append(mylst1[i])
            else:
                continue
        a=a[a.find("baseUrl"):a.find('"name"')-2]
        try:
            if lcode[0]!="languageCode:en":
                continue
            else:
                conn=a[a.find("https://"):]
                URL=conn
                page = requests.get(URL)
                mystring=str(page.content.decode("utf-8"))
                xtr=mystring.replace("&lt;","<").replace("&gt;",">").replace("&quot;",'"').replace("&apos;","'").replace("&amp;","&").replace("&#39;","'")
                xtr=list(xtr)
                ul=[]
                ll=[]
                for i in range(0,len(xtr)):
                    if xtr[i]=='<':
                        ll.append(i)
                    elif xtr[i]=='>':
                        ul.append(i)
                ll=sorted(ll,reverse=True)
                ul=sorted(ul,reverse=True)
                for k in range(0,len(ul)):
                    del xtr[ll[k]:ul[k]]
                mystr=""
                for i in range(0,len(xtr)):
                    mystr=mystr+str(xtr[i])

                mystr.replace("&#39;","'").replace("&quot;",'"')
                mystr=mystr.replace(">"," ").replace("&gt;"," ")
                mystr=mystr.replace("   "," ")
                mystr=mystr.replace("  "," ")
                mystr=mystr.replace("\n"," ")
                mystr=mystr.replace("&quot;",'"')
                mystr=mystr.replace("&amp;","&")
                mystr=mystr.replace(mystr[mystr.find("\u266a")]," ")
                try:
                    file=open(actual_path,'w')
                    file.write(mystr)
                    file.close()
                except:
                    # Change this line with the Windows path to your corpus folder 
                    file=open("C:/Users/surya/Downloads/YT_Corpus [All]/YT_Corpus [2017-2018]/failure.txt",'a')
                    file.write(vid+"\n")
                    file.close()

        except:
            continue
```

Part - 4 of the data files can be found here: [YoutTube Corpus](Data/YT_Corpus [All])

## Data Pre-Processing & Analysis

We start by pre-processing the data using data cleaning techniques like tokenisation, lemmetization, removing stopwords etc. Then we apply topic modelling techniques like Latent Dirichlet Allocation to get the top 10 words for both the SEC 10K and the YouTube data.

**Snippet to the Topic Modeling Code**

![](Media/Image2.jpg)

This generates a series of files from LDA based on Gibbs sampling  like Word Frequency, Doc2Topics, Topics2Probabilities, Topics2Terms etc. which we store here: [Example: Adobe Data Directory](Data/Text_Corpus/ADOBE_INC_796343) | [Example: YouTube IoT Data Directory](Data/YT_Corpus [All]/YT_Corpus [2017-2018]/IoT Platform)

This is followed by building a TF-IDF vectorizer as we are trying to extract some semantic meaning of the words (Reason why we didn't choose Bag of Words). Then we check for cosine similarity between the two documents (SEC & YouTube) by building a Document-Topic-Matrix (Sort of like a Document-Term-Matrix) for each company and compare the the similarity scores. The higher the value the better the chance of the technology emergence.

![](Media/Image3.jpg)

Cosine Similarity code can be found here (Cosine_Similarity.ipynb): [Similarity Analysis](Code/)

## Conclusion

Overall, this research study was a very good learning experience. I have learnt a lot about web-scraping and advanced python. Since 10K reports are very unorganized I had to find workarounds to scrape the data such that we do not lose any valuable information. I have also learned how to use some of the advanced libraries in R for data preprocessing. I learned about Topic Modelling and specifically about Latent Semantic Analysis (LSA) and Singular Value Decomposition (SVD), Latent Dirichlet Allocation (LDA), Cosine Similarity and how these techniques are used to make predictive text analytics. The next steps in the project are to apply statistical methods to predict the correlation between both the sources (10K and YouTube) on the emerging technologies and how these trends can be used to estimate the emergence.
