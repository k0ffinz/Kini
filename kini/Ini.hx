package kini;

class Ini {
	var contents:String;
	var i:Int;

	public static function parse(contents:String) {
		return new Ini(contents).doParse();
	}

	public static function toString(object:Dynamic) {
		var buffer = '';
		for (section in Reflect.fields(object)) {
			buffer += '[$section]\n';
			var data = Reflect.field(object, section);
			if (data is Array)
				for (array in (cast data : Array<Array<Dynamic>>))
					buffer += '${StringTools.replace(array.join(','), '"', '\\\\"')}\n';
			else
				for (field in Reflect.fields(data))
					buffer += '$field=${StringTools.replace(Std.string(Reflect.field(data, field)), '"', '\\\\"')}\n';
		}
		return buffer;
	}

	public static inline function stringify(object:Dynamic) {
		return toString(object);
	}

	public function new(contents:String) {
		// contents = new EReg('(?<=^|\\n)\\s+|\\s+(?:(\\n|$))', '').replace(contents, ''); // removing excess newlines
		contents = StringTools.replace(contents, '\r', ''); // fixing \r\n to just \n
		contents = new EReg('(?<!\\\\)(#|;).+', 'g').replace(contents, ''); // filtering comments out
		this.contents = contents;
		doParse();
	}

	public function doParse() {
		i = 0;
		var results:Dynamic = {};

		while (true) {
			var c = StringTools.fastCodeAt(contents, i);
			if (StringTools.isEof(c))
				break;
			if (c == '['.code) {
				i++; // skipping the [
				var sectionName = parseUntil(']'.code).buffer.toString();
				// trace('Reading section: $sectionName');
				i++; // skipping the newline
				var secStart = i;
				var sectionDataString = parseUntil('['.code).buffer.toString();
				// trace('Reading section data: $sectionDataString');
				i = secStart;
				var sectionData:Dynamic = null;
				var isArray = null;
				for (line in sectionDataString.split('\n')) {
					line = StringTools.trim(line);
					if (line == '' || line == '\n')
						continue;
					var keydata = parseStringUntil(line, '='.code);
					if (isArray == false)
						Reflect.setField(sectionData, StringTools.trim(keydata.buffer.toString()), StringTools.trim(parseStringUntil(line, '\n'.code, keydata.size + 1).buffer.toString()));
					else if (isArray == true)
						sectionData.push(CSVParser.parse(StringTools.trim(keydata.buffer.toString())));
					else {
						if (keydata.reached) {
							isArray = false;
							sectionData = {};
							Reflect.setField(sectionData, StringTools.trim(keydata.buffer.toString()), StringTools.trim(parseStringUntil(line, '\n'.code, keydata.size + 1).buffer.toString()));
						} else {
							isArray = true;
							sectionData = [];
							sectionData.push(CSVParser.parse(StringTools.trim(keydata.buffer.toString())));
						}
					}
				}
				i += sectionDataString.length - 1;
				Reflect.setField(results, sectionName, sectionData);
			}
			i++;
		}
		return results;
	}

	function parseUntil(char:Int) {
		var escapin = false;
		var reached = false;
		var buf = new StringBuf();
		while (true) {
			var curChar = StringTools.fastCodeAt(contents, i);
			if (StringTools.isEof(curChar))
				break;
			if (!escapin && curChar == char) {
				reached = true;
				break;
			}
			if (escapin)
				escapin = false;
			if (curChar == '\\'.code)
				escapin = true;
			buf.addChar(curChar);
			i++;
		}
		return {buffer: buf, reached: reached};
	}

	function parseStringUntil(str:String, char:Int, ?start:Int = 0) {
		var escapin = false;
		var reached = false;
		var buf = new StringBuf();
		var j = start;
		while (true) {
			var curChar = StringTools.fastCodeAt(str, j);
			if (StringTools.isEof(curChar))
				break;
			if (!escapin && curChar == char) {
				reached = true;
				break;
			}
			if (curChar == '\\'.code)
				escapin = true;
			buf.addChar(curChar);
			j++;
		}
		return {buffer: buf, reached: reached, size: j};
	}
}

class CSVParser {
	public static function parse(contents:String) {
		var values:Array<String> = [];
		var i = 0;
		var inside = false;
		var escaped = false;
		var buf = new StringBuf();
		while (!StringTools.isEof(StringTools.fastCodeAt(contents, i))) {
			var c = StringTools.fastCodeAt(contents, i);
			if (escaped) {
				buf.addChar(c);
				escaped = false;
				i++;
				continue;
			}
			switch c {
				case '\\'.code:
					escaped = true;
				case '"'.code:
					inside = !inside;
				case ','.code:
					if (inside) {
						i++;
						continue;
					}
					values.push(buf.toString());
					buf = new StringBuf();
				default:
					buf.addChar(c);
			}
			i++;
		}
		values.push(StringTools.trim(buf.toString()));
		return values;
	}
}
