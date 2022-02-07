function HEADER() {
    console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    console.log("SEL original data transfer (Version 1.0) \nproduce in 2020.12.22 by MouchenHung");
    console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
}

function FindFile(FILE) {
    var fs = require('fs');
    var files = fs.readdirSync(FILE);
    //console.log(files);
    return files;
}

function saveFile(file, DATA) {
    var fs = require('fs');
    fs.writeFile(file, DATA, 'utf-8', function(err, data) {
        if(err) {
            throw err;
        }
        console.log('Done!');
    })
}

function SEL_FORMAT_TRANS(JSONPATH, SAVEPATH) {
    var SELINFO_DATA = JSONPATH;
    //console.log("SELINFO_DATA = "+SELINFO_DATA);
    var output="Event ID\t\tTime Stamp\t\t\t\t\tSeverity\tSensor Name\t\t\tSensor Type\t\t\t\tDescription\r\n";
    //console.log("SELINFO_DATA.length = "+SELINFO_DATA.length);
    for (j = 0; j <= SELINFO_DATA.length; j++) {
        if (j >= SELINFO_DATA.length) {
            break;
        }
        var json = JSON.parse(JSON.stringify(SELINFO_DATA[j]));
        //console.log("content = "+JSON.stringify(SELINFO_DATA[j]));
        //console.log("severity = "+json.severity+"   event description = "+json.event);
        //Quanta Change
        //Change event parser to use common library libQuantaEventParser for sync all event messages are same
        if (json.record_type >= 0x0 &&
            json.record_type <= 0xBF) {
            //Range reserved for standard SEL Record Types

            //7-bit Event/Reading Type Code Range
            type = getbits(json.event_direction, 6, 0);
            if (type == 0x6F) {
                // Quanta ---
                if(json.sensor_type >= 0x1E && json.sensor_type <= 0x20)
                {
                    // This event is generated by OS, sensor num = 0x00, so can't grab sensor name
                    json.sensor_name = "OS";
                }
                // --- Quanta
            }

            /* Show sensor number if can't get sensor name(because no sdr) */
            //console.log("sensor_number=" +json.sensor_number);
            if(json.sensor_name == "Unknown")
                json.sensor_name = "#0x"+json.sensor_number;

            // --- Quanta
            sensortype = json.sensor_type;

        } else if (json.record_type >= 0xC0 &&json.record_type < 0xDF) {

            // Quanta++
            eventdesc = "";
            sensortype = "";

                /* SEL OEM Record - RecordType from 0xC0 to 0xDF */
                json.sensor_name = json.record_type.toString(16);
                for(var i = 3; i>=1; i--)
                {
                    /* OEMDefined[1]~OEMDefined[3] is ManufacturerID, display on SensorType field */
                    var tmpOEM = (i.toString(16));
                    while (tmpOEM.length < 2) {
                        tmpOEM = "0" + tmpOEM;
                    }

                    sensortype = sensortype + tmpOEM;
                }

            // Quanta--
        } else if (json.record_type == 0xDF) {
            //0xDF- Extended SEL records.
            sensortype = "Extended SEL";
        } else if (json.record_type >= 0xE0 &&
            json.record_type <= 0xFF) {
            // Quanta++
            sensortype = "";
        }
        var offset = json.utc_offset;
        var client_offset = new Date().getTimezoneOffset();
        var eventTimeStamp = json.timestamp;
        eventTimeStamp = eventTimeStamp + (client_offset*60);
        var a = new Date(eventTimeStamp * 1000);
        var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        var year = a.getFullYear();
        var month = months[a.getMonth()];
        var date = a.getDate();
        var hour = a.getHours();
        var min = a.getMinutes();
        var sec = a.getSeconds();
        if (sec < 10) {
            sec = "0" + sec;
        }
        if (min < 10) {
            min = "0" + min;
        }
        if (hour < 10) {
            hour = "0" + hour;
        }
        var formattedTime =month+"/"+date+"/"+year+"    "+hour + ':' + min + ':' + sec;

        if(!json.severity) json.severity = "N/A";
        if(!json.sensor_name) json.sensor_name = "N/A";
        if(!json.sensor_type) json.sensor_type = "N/A";

        output += "\t"+json.id;
        output += "\t\t" + formattedTime;
        output += "\t\t[" + json.severity+"]"; if (json.severity.length <=8) output += "\t";
        output += "\t[" + json.sensor_name+"]"; if (json.sensor_name.length < 8) output += "\t";
        output += "\t[" + json.sensor_type+"]"; if (json.sensor_type.length < 8) output += "\t";
        output += "\t" + json.event+"\r\n";
    }
    console.log(output);
    saveFile(SAVEPATH, output);
}

function MAIN() {
    var input_jsonfile,output_txtfile;
    var continueflag = 1;
    var args = process.argv;

    console.log('Start original SEL record transfer process');
    if (args.length == 4) {
        input_jsonfile = args[2];
        output_txtfile = args[3];
        console.log("--> manual file path given.");
    }
    else {    
        console.log("--> param non-given or invalid numbers of param, using DEFAULT path.");
        console.log("[tips] Could customize 2 parms [origSEL_path] [newSEL_path]");

        var Flst = FindFile("./log");
        if (Flst.length == 1) {
            input_jsonfile = "./log/"+Flst[0]+"/WebUI_SEL_TEXT_"+Flst[0];
            output_txtfile = "./SEL_TEXT.txt";
        }
        else {
            console.log("--> [ERROR] In ./log, more than two file, can't select folder automatically!");
            continueflag = 0;
        }

    }

    if (continueflag) {
        console.log("---------------------------------------------------------------------");
        console.log("Input JS File: "+input_jsonfile);
        console.log("Output JS File: "+output_txtfile);
        console.log("---------------------------------------------------------------------\n");
        const fs = require('fs');
        var rawStr = fs.readFileSync(input_jsonfile, 'utf8');
        var jsonfile = JSON.parse(rawStr.slice(rawStr.indexOf("[") - 1));
        SEL_FORMAT_TRANS(jsonfile, output_txtfile);
    }
}

HEADER();
MAIN();