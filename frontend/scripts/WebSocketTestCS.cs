using Godot;
using System;
using System.Collections.Generic;

public partial class WebSocketTestCS : Node
{
	WebSocketPeer ws;
	[Export] string url = "ws://localhost:8000/register_client";

	// Called when the node enters the scene tree for the first time.
	public override async void _Ready()
	{
		ws = new WebSocketPeer
		{
			InboundBufferSize = (int)Math.Pow(2, 21),
			OutboundBufferSize = (int)Math.Pow(2, 21),
			MaxQueuedPackets = 128
		};

        Error err = ws.ConnectToUrl(url);
		if (err != Error.Ok)
		{
			GD.Print("Error connecting to " + url);
			SetProcess(false);
			return;
		}


		var timeoutThreshold = 10;

		while (ws.GetReadyState() != WebSocketPeer.State.Open)
		{
			timeoutThreshold -= 1;
			GD.Print("Waiting for connection");
			await ToSignal(GetTree().CreateTimer(1.0), "timeout");
			if (timeoutThreshold <= 0)
			{
				GD.Print("Connection timeout");
				SetProcess(false);
				return;
			}
		}

		GD.Print("Connected to " + url);
		GD.Print("Sending message");

		var inferDict = new Dictionary<string, object>
		{
			{ "type", "infer" },
			{ "text_prompt", "Worker walks into a bar" },
			{ "num_samples", 1 },
			{ "packed_motion", new Dictionary<string, object>
				{
					{ "0", new List<List<double>>
						{
							new() { 0.006335, 0.925889, 0.022782 },
							new() { -1.848952, 5.855419, -2.209308 },
							new() { -2.225391, 0.251401, 2.091639 },
							new() { -1.218372, -0.323186, 12.9199 },
							new() { 7.476767, 15.311409000000001, 1.712001 },
							new() { 0.0, 0.0, 0.0 },
							new() { -2.184482, 1.651783, -23.240063 },
							new() { -2.814711, 1.391872, 20.864488 },
							new() { 4.163708, 2.049498, 16.159805 },
							new() { 0.0, 0.0, 0.0 },
							new() { 3.729861, -0.337432, 4.422964 },
							new() { 2.408384, -1.4252, 3.27613 },
							new() { -9.129623, -1.656823, 3.135745 },
							new() { 13.112406, -5.187206, -21.793815 },
							new() { 0.0, 0.0, 0.0 },
							new() { -11.362097, -26.660376, 10.556817 },
							new() { -51.782502, -43.877115, 14.017005 },
							new() { 132.977088, -62.445882, -104.782485 },
							new() { 0.0, 0.0, 0.0 },
							new() { 10.967079, 12.768552, 5.388521 },
							new() { 67.233545, 46.770885, 23.864491 },
							new() { -125.065474, 57.771444, -84.861314 },
							new() { 0.0, 0.0, 0.0 },
						}
					},
					{ "3", new List<List<double>>
						{
							new() { -0.005397, 0.923839, 0.038262 },
							new() { -2.944292, 11.688877, -0.744433 },
							new() { 1.330347, -0.54384, -6.42566 },
							new() { -2.461061, -1.037096, 25.45655 },
							new() { 5.155187, 11.443451, 3.14162 },
							new() { 0.0, 0.0, 0.0 },
							new() { -1.958387, 1.366517, -22.168222 },
							new() { -0.577779, 0.385054, 18.883832 },
							new() { 0.015543, -3.8655960000000005, 14.135998 },
							new() { 0.0, 0.0, 0.0 },
							new() { 3.4149730000000003, -0.55504, 6.905263 },
							new() { 1.382484, -0.791695, 1.400716 },
							new() { -7.933509000000001, 3.7116560000000005, 2.637238 },
							new() { 15.413932000000003, -4.118027, -28.096708 },
							new() { 0.0, 0.0, 0.0 },
							new() { -9.153748, -27.823949000000002, 9.350787 },
							new() { -43.505833, -49.495025, 12.898866 },
							new() { 64.612952, -57.545172, -38.580461 },
							new() { 0.0, 0.0, 0.0 },
							new() { 10.838178, 14.427333, 7.570341 },
							new() { 45.742547, 54.182692, 18.629589 },
							new() { -70.799916, 42.813622, -24.305144 },
							new() { 0.0, 0.0, 0.0 },
						}
					},
					{ "4", new List<List<double>>
						{
							new() { -0.001765, 0.925816, 0.054307 },
							new() { -3.725732, 12.670698, -2.237916 },
							new() { 4.608602, -0.474464, -6.318524 },
							new() { -5.343978, -0.430467, 28.755527000000004 },
							new() { 12.128289, 23.607741, 10.015787 },
							new() { 0.0, 0.0, 0.0 },
							new() { -0.879221, 1.500142, -21.414124 },
							new() { -1.14147, 0.476827, 21.571616 },
							new() { -0.540815, -5.032799, 15.559959 },
							new() { 0.0, 0.0, 0.0 },
							new() { 3.697301, -0.667363, 8.050449 },
							new() { 0.529855, -0.299849, 0.591786 },
							new() { -7.173179000000001, 6.867548, 3.730258 },
							new() { 16.663089000000003, -4.834545, -26.58799 },
							new() { 0.0, 0.0, 0.0 },
							new() { -8.517065, -28.319879000000004, 8.938752 },
							new() { -31.162397000000002, -46.34815, 7.183754999999999 },
							new() { 52.002, -53.22641500000001, -28.400572000000004 },
							new() { 0.0, 0.0, 0.0 },
							new() { 9.081599, 16.898637, 8.935075 },
							new() { 28.47988, 50.958105, 9.339571 },
							new() { -62.39294000000001, 46.62553, -22.598966 },
							new() { 0.0, 0.0, 0.0 },
						}
					},
					{ "9", new List<List<double>>
						{
							new() { 0.008035, 0.880018, 0.034304 },
							new() { -2.27324, 24.479031, -4.485215 },
							new() { 7.304753, -0.781987, -10.104969 },
							new() { -8.509794, -2.191417, 41.200228 },
							new() { 5.749923, 6.93057, -8.615016 },
							new() { 0.0, 0.0, 0.0 },
							new() { -9.876022, -2.184774, -28.880068999999995 },
							new() { 5.098005, -6.16919, 43.525683 },
							new() { -4.680638, -11.334446, 6.293945 },
							new() { 0.0, 0.0, 0.0 },
							new() { 3.232715, -0.610529, 7.64939 },
							new() { -6.456206, 2.968811, -1.032531 },
							new() { -3.360464, 18.495897, 5.631643 },
							new() { 23.504173, -9.795774, -19.990481 },
							new() { 0.0, 0.0, 0.0 },
							new() { -5.656359, -8.609517, -0.31699600000000006 },
							new() { -9.048457, -35.650475, -0.76012 },
							new() { 99.236589, -30.058303000000002, -45.053273 },
							new() { 0.0, 0.0, 0.0 },
							new() { -5.406511, 13.903595, 4.479021 },
							new() { 9.39165, 15.831369999999998, -0.41817 },
							new() { -14.650218000000002, 10.990762, -0.079215 },
							new() { 0.0, 0.0, 0.0 },
						}
					},
					{ "10", new List<List<double>>
						{
							new() { 0.004019, 0.872268, 0.025836 },
							new() { -1.755083, 27.3451, -2.633481 },
							new() { 7.145027000000001, -1.07325, -13.17809 },
							new() { -7.836206, -3.479632, 44.087649 },
							new() { 5.176777, 0.49769599999999997, -14.886387000000001 },
							new() { 0.0, 0.0, 0.0 },
							new() { -10.852122, -3.225971, -31.103845 },
							new() { 5.80187, -7.921004000000001, 46.706103 },
							new() { -6.359201, -14.977151000000001, 2.76627 },
							new() { 0.0, 0.0, 0.0 },
							new() { 3.435323, -0.5459680000000001, 6.583863 },
							new() { -9.047144, 3.9601350000000006, -2.3822130000000006 },
							new() { -2.988933, 18.627451000000004, 5.638191 },
							new() { 22.962958, -9.383703, -19.590579 },
							new() { 0.0, 0.0, 0.0 },
							new() { -8.58717, -5.944162, -2.686332 },
							new() { -3.7354569999999994, -35.300409, -2.001034 },
							new() { 102.827854, -21.3613, -35.058615 },
							new() { 0.0, 0.0, 0.0 },
							new() { -3.672455, 9.356965, 3.259471 },
							new() { 12.307579, 7.272943, -1.152276 },
							new() { -10.127301000000001, 9.465788, 0.134461 },
							new() { 0.0, 0.0, 0.0 },
						}
					}
				}
			}
		};
		
		// Dump as json string
		var inferJson = System.Text.Json.JsonSerializer.Serialize(inferDict);

		Error err2 = ws.SendText(inferJson);
		if (err2 != Error.Ok)
		{
			GD.Print("Error sending message");
			SetProcess(false);
			return;
		}
		GD.Print("Message sent, waiting for response in _Process");
		SetProcess(true);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		ws.Poll();

		if (ws.GetAvailablePacketCount() > 0)
		{
			byte[] packet = ws.GetPacket();
			string packet_str = System.Text.Encoding.UTF8.GetString(packet);
			GD.Print("As string " + packet_str);  // Overflows Editor Output.. oops ´\_(ツ)_/¯
		}

		if (ws.GetReadyState() == WebSocketPeer.State.Closed)
		{
			GD.Print("Connection closed: [", ws.GetCloseCode(), "] ", ws.GetCloseReason());
			SetProcess(false);
		}
	}
}
